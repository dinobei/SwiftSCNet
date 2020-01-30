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

open class ServerSession: NSObject {
    var isMainServerSession: Bool = false
    var sessionIndex: Int32 = 0
    
    let client: TCPClient?
    let queue: BlockingQueue<Message>
    var isInterrupted: Bool = true
    var isSRThreadInterrupted: Bool = true
   
    var serverSessionDelegate: ServerSessionDelegate?
    var serverManagerDelegate: ServerManagerDelegate?
    
    let registry = Registry.sharedInstance
    
    var isFinished = true
    
    public init(ip: String, port: Int32, delegate: ServerSessionDelegate) {
        self.client = TCPClient(address: ip, port: port)
        self.queue = BlockingQueue<Message>()
        
        self.isMainServerSession = true
        self.serverSessionDelegate = delegate
    }
    
    public init(sessionIndex: Int32, ip: String, port: Int32, delegate: ServerManagerDelegate) {
        self.client = TCPClient(address: ip, port: port)
        self.queue = BlockingQueue<Message>()

        self.isMainServerSession = false
        self.sessionIndex = sessionIndex
        self.serverManagerDelegate = delegate
    }

    public func start(timeout: Int) {
        guard let client = self.client else {
            return
        }
        
        isFinished = false
        isInterrupted = false
        while !isInterrupted {
            
            if isMainServerSession { self.serverSessionDelegate?.onAttaching?() }
            else { self.serverManagerDelegate?.onAttaching?(sessionIndex) }
            
            let beforeDate = Date()
            switch client.connect(timeout: timeout) {
            case .success:
                if isMainServerSession { self.serverSessionDelegate?.onAttached?() }
                else { self.serverManagerDelegate?.onAttached?(sessionIndex) }
                
            case .failure(_):
                let afterDate = Date()
                
                if isMainServerSession { self.serverSessionDelegate?.onAttachFailed?() }
                else { self.serverManagerDelegate?.onAttachFailed?(sessionIndex) }
                
                
                let takeTime = afterDate.timeIntervalSince1970 - beforeDate.timeIntervalSince1970
                if Double(timeout) > takeTime {
                    Thread.sleep(forTimeInterval: Double(timeout) - takeTime)
                }
                continue
            }
            
            self.queue.removeAll()
            let group = DispatchGroup()
            group.enter()
            group.enter()
            
            self.isSRThreadInterrupted = false
            DispatchQueue.global(qos: .default).async { // send
                
                while !self.isSRThreadInterrupted {

                    do {
                        let req = try self.queue.take(1)
                        if try !self.send(request: req) {
                            self.isSRThreadInterrupted = true
                            print("Disconnected from server (in sendThread)")
                            break
                        }
                    }
                    catch(_) {
                        // timeout SendThread
                    }
                }
                
                print("send thread finished")
                group.leave()
            }
            
            DispatchQueue.global(qos: .default).async { // recv
                while !self.isSRThreadInterrupted {
                    do {
                        guard let (messageHeader, data) = try self.recv() else {
                            // timeout RecvThread
                            self.serverSessionDelegate?.onTimedOut?()
                            continue
                        }

                        guard let messageType = MESSAGE_TYPE(rawValue: Int32(messageHeader.messageType)) else {
                            print("Unknown message type")
                            break
                        }
                        
                        switch messageType {
                        case .RAWBYTE:
                            do {
                                try self.registry.getRawByteCallback(packetType: Int32(messageHeader.packetType))?(messageHeader.connectionID, data)
                            }
                            catch {
                            }
                        case .PROTOBUF:
                            do {
                                let messageType = try self.registry.getMessageType(packetType: Int32(messageHeader.packetType))
                                let message = try messageType.init(serializedData: Data(data))
                                let callback = try self.registry.getProtobufCallback(packetType: Int32(messageHeader.packetType))
                                callback?(messageHeader.connectionID, message)
                            }
                            catch {
                            }
                        default:
                            ()
                        }
                    }
                    catch _ {
                        print("Disconnected from server (in recvThread)")
                        self.isSRThreadInterrupted = true
                        break
                    }
                }
                
                print("recv thread finished")
                group.leave()
            }

            group.wait()
            
            client.close()
        }
        
        if self.isMainServerSession { self.serverSessionDelegate?.onDetached?() }
        else { self.serverManagerDelegate?.onDetached?(sessionIndex) }
        
        // clean up
        client.close()
        isFinished = true
    }
    
    public func request(_ message: Message) {
        self.queue.add(message)
    }

    public func request(packetType: Int32, message: String) throws {
        if( try !send(packetType: packetType, message: message)) {
            print("send failed")
        }
    }
    
    public func interrupt() {
        isInterrupted = true
        isSRThreadInterrupted = true
        self.client?.close()
        while !isFinished {
            sleep(1)
        }
    }
    
    private func send(request: Message) throws -> Bool {
        guard let client = self.client else {
            return false
        }
        
        let packetType = try registry.getPacketType(request)
        
        var request_data = try request.serializedData()
        let packetSizeArr = encodeVarint(Int32(request_data.count))
        let packetTypeArr = encodeVarint(packetType)
        let messageTypeArr = encodeVarint(MESSAGE_TYPE.PROTOBUF.rawValue)
        let cryptTypeArr = encodeVarint(0)
        let connectionIDArr = encodeVarint(0)
        request_data.insert(contentsOf: connectionIDArr, at: 0)
        request_data.insert(contentsOf: cryptTypeArr, at: 0)
        request_data.insert(contentsOf: messageTypeArr, at: 0)
        request_data.insert(contentsOf: packetTypeArr, at: 0)
        request_data.insert(contentsOf: packetSizeArr, at: 0)
        request_data.insert(MAGIC_PACKET[1], at: 0)
        request_data.insert(MAGIC_PACKET[0], at: 0)
        
        let result = client.send(data: request_data)
        return result.isSuccess
    }
    
    private func send(packetType: Int32, message: String) throws -> Bool {
        guard let client = self.client else {
            return false
        }

        var data = Array(message.utf8)
        let packetSizeArr = encodeVarint(Int32(message.count))
        let packetTypeArr = encodeVarint(packetType)
        let messageTypeArr = encodeVarint(MESSAGE_TYPE.RAWBYTE.rawValue)
        let cryptTypeArr = encodeVarint(0)
        let connectionIDArr = encodeVarint(0)
        data.insert(contentsOf: connectionIDArr, at: 0)
        data.insert(contentsOf: cryptTypeArr, at: 0)
        data.insert(contentsOf: messageTypeArr, at: 0)
        data.insert(contentsOf: packetTypeArr, at: 0)
        data.insert(contentsOf: packetSizeArr, at: 0)
        data.insert(MAGIC_PACKET[1], at: 0)
        data.insert(MAGIC_PACKET[0], at: 0)

        let result = client.send(data: data)
        return result.isSuccess
    }
    
    private func recv() throws -> (MessageHeader, ArraySlice<UInt8>)? {
        guard let client = self.client else {
            return nil
        }
        guard let magicPacket = try client.read(MAGIC_PACKET_LENGTH, timeout: 1),
            magicPacket[0] == MAGIC_PACKET[0],
            magicPacket[1] == MAGIC_PACKET[1] else {
            return nil
        }
        
        var receivedHeaderComponent = 0
        
        var headerBuffer: [[UInt8]] = []
        for _ in 0 ..< HEADER_ELEMENTS {
            headerBuffer.append([])
        }
    
        var singleItemSize = 0
        while true {
            guard let _data = try client.read(1, timeout: 1),
                  let data = _data.first else {
                return nil
            }
            
            headerBuffer[receivedHeaderComponent].append(data)
            
            if (data&0xFF) > 127 {
                singleItemSize += 1
                guard singleItemSize <= 7 else {
                    return nil
                }
                continue
            }
            
            singleItemSize = 0
            receivedHeaderComponent += 1
            
            if receivedHeaderComponent == HEADER_ELEMENTS {
                break
            }
        }
    
        // get MessageHeader
        let messageHeader = MessageHeader(dataSize: decodeVarint(headerBuffer[0]),
                                          packetType: decodeVarint(headerBuffer[1]),
                                          messageType: decodeVarint(headerBuffer[2]),
                                          cryptType: decodeVarint(headerBuffer[3]),
                                          connectionID: decodeVarint(headerBuffer[4]))
        if messageHeader.dataSize == 0 {
            let emptyData = ArraySlice<UInt8>()
            return (messageHeader, emptyData)
        }
        
        var totalData: [Byte] = []
        totalData.reserveCapacity(messageHeader.dataSize)
        var readCount = 0
        while true {
            guard let partialData = try client.read(messageHeader.dataSize - readCount, timeout: 5) else {
                return nil
            }
            
            totalData.append(contentsOf: partialData)
            readCount += partialData.count
            if readCount >= messageHeader.dataSize {
                break
            }
            
        }
        
        return (messageHeader, totalData[0...totalData.count])
    }
    
}
