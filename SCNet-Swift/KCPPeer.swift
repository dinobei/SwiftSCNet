//
//  KCPPeer.swift
//  iOS SCNet_Swift
//
//  Created by pbj on 14/03/2019.
//  Copyright © 2019 ijoon. All rights reserved.
//

import Foundation
import SwiftSocket

class KCPPeer {
    let ip: String
    let port: Int
    let key: String
    
    var kcp: IKCPCB
    var lastPing: Int
    
    let date = Date()
    let udpClient: UDPClient
    
    required init(_ udpClient: UDPClient, ip: String, port: Int) {
        self.udpClient = udpClient
        
        self.ip = ip
        self.port = port
        self.key = "\(ip):\(port)"

        self.kcp = IKCPCB.init(conv: 0x11223344, user: 0)
        let _ = self.kcp.wndSize(sndwnd: 128, rcvwnd: 128)
        let _ = self.kcp.nodelay(nodelay: 1, internalVal: 20, resend: 2, nc: 1)
        
        lastPing = 0
        
        self.kcp.output = {
            (buf: [UInt8],kcp: inout IKCPCB,user: UInt64) -> Int in
            let _ = self.udpClient.send(ip: self.ip, port: self.port, data: buf)
            
            return 0
        }
    }

    func send(connectionID: Int, packetType: RendezvousPacketType, data: String) -> Bool {
        return send(connectionID: Int32(connectionID), packetType: Int32(packetType.rawValue), message: data)
    }

    fileprivate func send(connectionID: Int32, packetType: Int32, message: String) -> Bool {
        
        var data = Array(message.utf8)
        let packetSizeArr = encodeVarint(Int32(message.count))
        let packetTypeArr = encodeVarint(packetType)
        let messageTypeArr = encodeVarint(MESSAGE_TYPE.RAWBYTE.rawValue)
        let cryptTypeArr = encodeVarint(0)
        let connectionIDArr = encodeVarint(Int32(connectionID))
        data.insert(contentsOf: connectionIDArr, at: 0)
        data.insert(contentsOf: cryptTypeArr, at: 0)
        data.insert(contentsOf: messageTypeArr, at: 0)
        data.insert(contentsOf: packetTypeArr, at: 0)
        data.insert(contentsOf: packetSizeArr, at: 0)
        data.insert(Array(MAGIC_PACKET.utf8)[1], at: 0)
        data.insert(Array(MAGIC_PACKET.utf8)[0], at: 0)
        
        let result = kcp.send(buffer: Data(data))
        if result < 0 {
            return false
        }
        return true
    }
    
    
    func getKey() -> String {
        return key
    }
}

