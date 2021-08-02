//
//  CoreClient.swift
//  SCNet-Swift
//
//  Created by pbj on 2018. 8. 13..
//  Copyright © 2018년 ijoon. All rights reserved.
//

import Foundation
import SwiftSocket
import SwiftProtobuf

open class Client: NSObject {
    
    let tcpClient: TCPClient?
    var isInterrupted: Bool = true
    var recvThreadInterrupted: Bool = true
   
    var clientDelegate: ClientDelegate?
    
    let registry = Registry.sharedInstance
    
    var callbackKeyRef: Int32 = 1
    
    struct CallbackContext {
        var onReceived: Registry.Callback
        var onTimeout: Registry.EventCallback?
        var onEnded: Registry.EventCallback?
        var reqUts: TimeInterval;
        var resUts: TimeInterval;
        var timeout: TimeInterval;
        var ctxTimeout: TimeInterval;
    }
    
    var cbCtxMap = [Int32:CallbackContext]()
    
    var _connected = false
    open var connected: Bool {
        get {
            return _connected
        }
    }
    
    var isFinished = true
    var ping: TimeInterval;
    
    public init(ip: String, port: Int32, delegate: ClientDelegate) {
        self.ping = Date().timeIntervalSince1970
        self.tcpClient = TCPClient(address: ip, port: port)
        self.clientDelegate = delegate
    }

    public func start(timeout: Int) {
        guard let client = self.tcpClient else {
            return
        }
        
        self._connected = false
        isFinished = false
        isInterrupted = false
        while !isInterrupted {
            
            self.clientDelegate?.onAttaching?()
            
            let beforeDate = Date()
            switch client.connect(timeout: timeout) {
            case .success:
                self._connected = true
                self.clientDelegate?.onAttached?()
                
            case .failure(_):
                self._connected = false
                let afterDate = Date()
                
                self.clientDelegate?.onAttachFailed?()
                
                let takeTime = afterDate.timeIntervalSince1970 - beforeDate.timeIntervalSince1970
                if Double(timeout) > takeTime {
                    Thread.sleep(forTimeInterval: Double(timeout) - takeTime)
                }
                continue
            }
            
            let group = DispatchGroup()
            group.enter()
            
            self.recvThreadInterrupted = false
            DispatchQueue.global(qos: .default).async {
                var prevTime = Date().timeIntervalSince1970
                while !self.recvThreadInterrupted {
                    do {
                        guard let (header, message) = try self.recv() else {
                            self.updateCallbackContextMap()
                            
                            // timeout RecvThread
                            if self.ping + TimeInterval(timeout) < Date().timeIntervalSince1970 {
                                self.clientDelegate?.onTimedOut?()
                            }
                            continue
                        }
                        
                        let currentTime = Date().timeIntervalSince1970
                        if prevTime + 1 < currentTime {
                            prevTime = currentTime
                            self.updateCallbackContextMap()
                        }
                        
                        self.ping = Date().timeIntervalSince1970

                        do {
                            if var cbCtx = self.cbCtxMap[header.resOf] {
                                cbCtx.resUts = Date().timeIntervalSince1970
                                cbCtx.onReceived(header, message)
                                self.cbCtxMap[header.resOf] = cbCtx
                            }
                            else if let callback = try self.registry.getCallback(packetType: header.packetType) {
                                callback(header, message)
                            }
                        }
                        catch {
                        }
                    }
                    catch _ {
                        // Disconnected from server (in recvThread)
                        self.recvThreadInterrupted = true
                        break
                    }
                }
                
                // recv thread finished
                group.leave()
                
                self._connected = false
            }

            group.wait()
            
            client.close()
        }
        
        // clean up
        client.close()
        isFinished = true
        self.clientDelegate?.onDetached?()
    }
    
    public func interrupt() {
        isInterrupted = true
        recvThreadInterrupted = true
        self.tcpClient?.close()
//        while !isFinished {
//            sleep(1)
//        }
    }
    
    public func send(header _header: Header?, message: Message,
                     onReceived: Registry.Callback? = nil,
                     onTimeout: Registry.EventCallback? = nil,
                     onEnded: Registry.EventCallback? = nil) throws -> Bool {
        guard let tcpClient = self.tcpClient else {
            return false
        }

        let packetType = try registry.getPacketType(message)
        var header = Header()
        header.packetType = packetType
        if let _header = _header {
            header.resOf = _header.id
        }
        if let onReceived = onReceived {
            let currentTime = Date().timeIntervalSince1970
            let cbCtx = CallbackContext(onReceived: onReceived,
                                        onTimeout: onTimeout,
                                        onEnded: onEnded,
                                        reqUts: currentTime,
                                        resUts: 0,
                                        timeout: 3,
                                        ctxTimeout: 3600)
            cbCtxMap[callbackKeyRef] = cbCtx
            header.id = callbackKeyRef
            callbackKeyRef += 1
        }
        
        var packetData = try header.serializedData()
        let headerSize = packetData.count
        packetData.append(try message.serializedData())
        let packetSize = packetData.count
        
        let header_size_arr: [UInt8] = [UInt8((headerSize >> 8) & 0xFF),
                                        UInt8(headerSize & 0xFF)];
        let packet_size_arr: [UInt8] = [UInt8((packetSize >> 24) & 0xFF),
                                        UInt8((packetSize >> 16) & 0xFF),
                                        UInt8((packetSize >> 8) & 0xFF),
                                        UInt8(packetSize & 0xFF)]
        packetData.insert(contentsOf: header_size_arr, at: 0)
        packetData.insert(contentsOf: packet_size_arr, at: 0)
        packetData.insert(MAGIC_PACKET[1], at: 0)
        packetData.insert(MAGIC_PACKET[0], at: 0)
        
        let result = tcpClient.send(data: packetData)
        return result.isSuccess
    }
    
    public func send(message: Message,
                     onReceived: Registry.Callback? = nil,
                     onTimeout: Registry.EventCallback? = nil,
                     onEnded: Registry.EventCallback? = nil) throws -> Bool {
        return try send(header: nil, message: message, onReceived: onReceived, onTimeout: onTimeout, onEnded: onEnded)
    }
    
    private func recv() throws -> (Header, Message)? {
        guard let tcpClient = self.tcpClient else {
            return nil
        }
        
        let headLength = MAGIC_PACKET_LENGTH + 4 + 2
        
        guard let headPacket = try tcpClient.read(headLength, timeout: 1),
              headPacket[0] == MAGIC_PACKET[0],
              headPacket[1] == MAGIC_PACKET[1] else {
            return nil
        }
        
        let packetSize = Int(headPacket[2] << 24 | headPacket[3] << 16 | headPacket[4] << 8 | headPacket[5])
        let headerSize = Int(headPacket[6] << 8 | headPacket[7])

        var packet: [Byte] = []
        if packetSize > 0 {
            packet.reserveCapacity(packetSize)
            guard let pkt = try tcpClient.read(packetSize, timeout: 1) else {
                return nil
            }
            packet = pkt
        }
        
        do {
            let header = try Header.self.init(serializedData: Data(packet[0..<headerSize]))
            let messageType = try self.registry.getMessageType(packetType: header.packetType)
            let message = try messageType.init(serializedData: Data(packet[headerSize..<packetSize]))
            return (header, message)
        }
        catch {
        }
        
        return nil
    }
    
    private func updateCallbackContextMap() {
        for (key, cbCtx) in self.cbCtxMap {
            let reqUts = cbCtx.reqUts
            let resUts = cbCtx.resUts
            let timeoutMs = cbCtx.timeout
            let ctxTimeoutMs = cbCtx.ctxTimeout
            
            let currentTime = Date().timeIntervalSince1970
            if resUts == 0 {
                if reqUts + timeoutMs < currentTime {
                    cbCtx.onTimeout?()
                    self.cbCtxMap.removeValue(forKey: key)
                }
            } else {
                if resUts + ctxTimeoutMs < currentTime {
                    cbCtx.onEnded?()
                    self.cbCtxMap.removeValue(forKey: key)
                }
            }
        }
    }
}
