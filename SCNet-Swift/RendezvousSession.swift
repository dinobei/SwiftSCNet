//
//  RendezvousSession.swift
//  iOS SCNet_Swift
//
//  Created by pbj on 14/03/2019.
//  Copyright © 2019 ijoon. All rights reserved.
//

import Foundation

open class RendezvousSession: NSObject {
    let connectionID: Int
    
    var publicKCPPeer: KCPPeer?
    var privateKCPPeer: KCPPeer?
    var relayKCPPeer: KCPPeer?
    
    public required init(connectionID: Int) {
        self.connectionID = connectionID
    }
    
    public func isConnected() -> Bool {
        return relayKCPPeer != nil || publicKCPPeer != nil || privateKCPPeer != nil
    }
    
    public func getConnectionID() -> Int {
        return connectionID
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
}
