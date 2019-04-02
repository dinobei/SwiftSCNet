//
//  RendezvousSession.swift
//  iOS SCNet_Swift
//
//  Created by pbj on 14/03/2019.
//  Copyright © 2019 ijoon. All rights reserved.
//

import Foundation
import SwiftProtobuf

open class RendezvousSession: NSObject {
    let connectionID: Int
    fileprivate let lock = NSLock()
    fileprivate let registry = Registry.sharedInstance
    
    fileprivate var _publicKCPPeer: KCPPeer?
    var publicKCPPeer: KCPPeer? {
        get {
            lock.lock()
            let kcpPeer = _publicKCPPeer
            lock.unlock()
            return kcpPeer
        }
        
        set(newKcpPeer) {
            lock.lock()
            _publicKCPPeer = newKcpPeer
            lock.unlock()
        }
    }
    
    fileprivate var _privateKCPPeer: KCPPeer?
    var privateKCPPeer: KCPPeer? {
        get {
            lock.lock()
            let kcpPeer = _privateKCPPeer
            lock.unlock()
            return kcpPeer
        }
        
        set(newKcpPeer) {
            lock.lock()
            _privateKCPPeer = newKcpPeer
            lock.unlock()
        }
    }
    
    fileprivate var _relayKCPPeer: KCPPeer?
    var relayKCPPeer: KCPPeer? {
        get {
            lock.lock()
            let kcpPeer = _relayKCPPeer
            lock.unlock()
            return kcpPeer
        }
        
        set(newKcpPeer) {
            lock.lock()
            _relayKCPPeer = newKcpPeer
            lock.unlock()
        }
    }
    
    public func getPublicAddress() -> String? {
        return publicKCPPeer?.getKey()
    }
    
    public func getPrivateAddress() -> String? {
        return privateKCPPeer?.getKey()
    }
    
    public func getRelayAddress() -> String? {
        return relayKCPPeer?.getKey()
    }
    
    public required init(connectionID: Int) {
        self.connectionID = connectionID
    }
    
    public func isConnected() -> Bool {
        return relayKCPPeer != nil || publicKCPPeer != nil || privateKCPPeer != nil
    }
    
    public func getConnectionID() -> Int {
        return connectionID
    }
    
    public func send(request: Message) throws -> Bool {
        if let kcpPeer = privateKCPPeer {
            return try send(kcpPeer, request: request, isRelay: false)
        }
        else if let kcpPeer = publicKCPPeer {
            return try send(kcpPeer, request: request, isRelay: false)
        }
        else if let kcpPeer = relayKCPPeer {
            return try send(kcpPeer, request: request, isRelay: true)
        }
        
        return false
    }
    
    fileprivate func send(_ kcpPeer: KCPPeer, request: Message, isRelay: Bool) throws -> Bool {
        
        let packetType = try registry.getPacketType(request)
        
        var request_data = try request.serializedData()
        let packetSizeArr = encodeVarint(Int32(request_data.count))
        let packetTypeArr = encodeVarint(packetType)
        let messageTypeArr = encodeVarint(isRelay ? MESSAGE_TYPE.PROTOBF_RELAY.rawValue : MESSAGE_TYPE.PROTOBUF.rawValue)
        let cryptTypeArr = encodeVarint(0)
        let connectionIDArr = encodeVarint(Int32(connectionID))
        request_data.insert(contentsOf: connectionIDArr, at: 0)
        request_data.insert(contentsOf: cryptTypeArr, at: 0)
        request_data.insert(contentsOf: messageTypeArr, at: 0)
        request_data.insert(contentsOf: packetTypeArr, at: 0)
        request_data.insert(contentsOf: packetSizeArr, at: 0)
        request_data.insert(Array(MAGIC_PACKET.utf8)[1], at: 0)
        request_data.insert(Array(MAGIC_PACKET.utf8)[0], at: 0)
        
        kcpPeer.lock.lock()
        let result = kcpPeer.kcp.send(data: Data(request_data))
        kcpPeer.lock.unlock()
        if result < 0 {
            return false
        }
        return true
    }
}
