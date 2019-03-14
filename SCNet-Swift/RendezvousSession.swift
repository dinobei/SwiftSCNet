//
//  RendezvousSession.swift
//  iOS SCNet_Swift
//
//  Created by pbj on 14/03/2019.
//  Copyright © 2019 ijoon. All rights reserved.
//

import Foundation

class RendezvousSession {
    let connectionID: Int
    
    var publicKCPPeer: KCPPeer?
    var privateKCPPeer: KCPPeer?
    var relayKCPPeer: KCPPeer?
    
    required init(connectionID: Int) {
        self.connectionID = connectionID
    }
    
    func isConnected() -> Bool {
        return relayKCPPeer != nil || publicKCPPeer != nil || privateKCPPeer != nil
    }
    
    func getConnectionID() -> Int {
        return connectionID
    }
    
    func getPublicAddress() -> String? {
        return publicKCPPeer?.getKey()
    }
    
    func getPrivateAddress() -> String? {
        return privateKCPPeer?.getKey()
    }
    
    func getRelayAddress() -> String? {
        return relayKCPPeer?.getKey()
    }
}
