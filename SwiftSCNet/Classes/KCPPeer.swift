//
//  KCPPeer.swift
//  iOS SCNet_Swift
//
//  Created by pbj on 14/03/2019.
//  Copyright © 2019 ijoon. All rights reserved.
//

import Foundation
import SwiftSocket
import SwiftProtobuf
import SwiftKcp

class KCPPeer: KcpOutputer {
    let ip: String
    let port: Int
    let key: String
    
    let lock: NSLock = NSLock()
    var kcp: Kcp
    var lastPing: Int64
    
    let date = Date()
    let udpClient: UDPClient
    
    let registry = Registry.sharedInstance
    
    required init(_ udpClient: UDPClient, ip: String, port: Int) {
        self.udpClient = udpClient
        
        self.ip = ip
        self.port = port
        self.key = "\(ip):\(port)"
        
        lastPing = Date().millisecondsSince1970

        self.kcp = Kcp(conv: 0x11223344, recvBufferSize: Int32(MAX_PACKET_SIZE))
        let _ = self.kcp.wndSize(sndwnd: 128, rcvwnd: 128)
        let _ = self.kcp.noDelay(nodelay: 1, interval: 20, resend: 2, nc: 1)
        self.kcp.outputer(self)
    }

    func send(connectionID: Int, packetType: RendezvousPacketType, data: String?) -> Bool {
        return send(connectionID: Int32(connectionID), packetType: Int32(packetType.rawValue), message: data)
    }

    fileprivate func send(connectionID: Int32, packetType: Int32, message: String?) -> Bool {
        
        var data = [UInt8]()
        var packetSize: Int32 = 0
        if let message = message {
            data = Array(message.utf8)
            packetSize = Int32(message.count)
        }
        let packetSizeArr = encodeVarint(packetSize)
        let packetTypeArr = encodeVarint(packetType)
        let messageTypeArr = encodeVarint(MESSAGE_TYPE.RAWBYTE.rawValue)
        let cryptTypeArr = encodeVarint(0)
        let connectionIDArr = encodeVarint(Int32(connectionID))
        data.insert(contentsOf: connectionIDArr, at: 0)
        data.insert(contentsOf: cryptTypeArr, at: 0)
        data.insert(contentsOf: messageTypeArr, at: 0)
        data.insert(contentsOf: packetTypeArr, at: 0)
        data.insert(contentsOf: packetSizeArr, at: 0)
        data.insert(MAGIC_PACKET[1], at: 0)
        data.insert(MAGIC_PACKET[0], at: 0)
        
        lock.lock()
        let result = kcp.send(data: Data(data))
        lock.unlock()
        if result < 0 {
            return false
        }
        return true
    }
    
    func send(connectionID: Int32, request: Message) throws -> Bool {
        
        let packetType = try registry.getPacketType(request)
        
        var request_data = try request.serializedData()
        let packetSizeArr = encodeVarint(Int32(request_data.count))
        let packetTypeArr = encodeVarint(packetType)
        let messageTypeArr = encodeVarint(MESSAGE_TYPE.PROTOBUF.rawValue)
        let cryptTypeArr = encodeVarint(0)
        let connectionIDArr = encodeVarint(connectionID)
        request_data.insert(contentsOf: connectionIDArr, at: 0)
        request_data.insert(contentsOf: cryptTypeArr, at: 0)
        request_data.insert(contentsOf: messageTypeArr, at: 0)
        request_data.insert(contentsOf: packetTypeArr, at: 0)
        request_data.insert(contentsOf: packetSizeArr, at: 0)
        request_data.insert(MAGIC_PACKET[1], at: 0)
        request_data.insert(MAGIC_PACKET[0], at: 0)
        
        lock.lock()
        let result = kcp.send(data: Data(request_data))
        lock.unlock()
        if result < 0 {
            return false
        }
        return true
    }
    
    func getKey() -> String {
        return key
    }
    
    func kcp(kcp: Kcp, outputData: Data) -> Int {
        let array = [UInt8](outputData)
        let _ = self.udpClient.send(ip: self.ip, port: self.port, data: array)
        return 0
    }
}

