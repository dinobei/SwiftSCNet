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

open class ClientManager: NSObject {
    let client: TCPClient?
    let queue: BlockingQueue<Message>
    var isInterrupted: Bool = true
    var isSRThreadInterrupted: Bool = true
   
    var delegate: ClientManagerDelegate
    
    public init(ip: String, port: Int32, delegate: ClientManagerDelegate) {
        self.client = TCPClient(address: ip, port: port)
        self.queue = BlockingQueue<Message>()
        self.delegate = delegate
    }

    public func start(timeout: Int) {
        guard let client = self.client else {
            return
        }
        
        isInterrupted = false
        while !isInterrupted {
            
            self.delegate.onAttaching?()
            let beforeDate = Date()
            switch client.connect(timeout: timeout) {
            case .success:
                self.delegate.onAttached?()
            case .failure(_):
                let afterDate = Date()
                
                self.delegate.onAttachFailed?()
                
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
                            continue
                        }
                        
                        self.delegate.onCallback?(messageHeader: messageHeader, data: data)
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
        
        self.delegate.onDetached?()
        
        // clean up
        client.close()
    }
    
    public func control(req: Message) {
        self.queue.add(req)
    }

    public func detach() {
        isInterrupted = true
        isSRThreadInterrupted = true
    }
    
    public func send(request: Message) throws -> Bool {
        guard let client = self.client else {
            return false
        }
        
        let typeInt = try Registry.sharedInstance.getTypeInt(message: request)
        
        var request_data = try request.serializedData()
        let packetSizeArr = encodeVarint(Int32(request_data.count))
        let packetTypeArr = encodeVarint(typeInt)
        let cryptTypeArr = encodeVarint(0)
        request_data.insert(contentsOf: cryptTypeArr, at: 0)
        request_data.insert(contentsOf: packetTypeArr, at: 0)
        request_data.insert(contentsOf: packetSizeArr, at: 0)
        
        let result = client.send(data: request_data)
        return result.isSuccess
    }
    
    public func recv() throws -> (MessageHeader, [UInt8])? {
        guard let client = self.client else {
            return nil
        }
        
        var receivedHeaderComponent = 0
        
        var headerBuffer: [[UInt8]] = []
        for _ in 0 ..< HEADER_ELEMENTS {
            headerBuffer.append([])
        }
    
        while true {
            guard let _data = try client.read(1, timeout: 1),
                  let data = _data.first else {
                return nil
            }
            
            headerBuffer[receivedHeaderComponent].append(data)
            
            if data > 127 {
                continue
            }
            
            receivedHeaderComponent += 1
            
            if receivedHeaderComponent == HEADER_ELEMENTS {
                break
            }
        }
    
        // get MessageHeader
        let messageHeader = MessageHeader(dataSize: decodeVarint(headerBuffer[0]), packetType: decodeVarint(headerBuffer[1]), cryptType: decodeVarint(headerBuffer[2]))
        
        guard let data = try client.read(messageHeader.dataSize) else {
            return nil
        }
        
        return (messageHeader, data)
    }
    
}
