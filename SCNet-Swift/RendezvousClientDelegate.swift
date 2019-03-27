//
//  RendezvousClientDelegate.swift
//  iOS SCNet_Swift
//
//  Created by pbj on 15/03/2019.
//  Copyright © 2019 ijoon. All rights reserved.
//

import Foundation

@objc public protocol RendezvousClientDelegate {
    @objc optional func onConnectedToRendezvousServer(_ myPublicIP: String, _ myPublicPort: String)
    @objc optional func onTargetInvalid(_ targetIP: String, _ targetPort: Int)
    @objc optional func onConnectionIDCreated(_ rendezvousSession: RendezvousSession, _ targetIP: String, _ targetPort: Int)
    @objc optional func onConnecting(_ connectionID: Int)
    @objc optional func onConnected(_ rendezvousSession: RendezvousSession, _ connection: Connection)
    @objc optional func onConnectionUpdate(_ rendezvousSession: RendezvousSession, _ connection: Connection)
    
    @objc optional func onConnectionRemoved(_ rendezvousSession: RendezvousSession, _ connection: Connection)
    @objc optional func onDisconnected(_ connectionID: Int)
}
