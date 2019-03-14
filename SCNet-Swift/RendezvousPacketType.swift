//
//  RendezvousPacketType.swift
//  iOS SCNet_Swift
//
//  Created by pbj on 14/03/2019.
//  Copyright © 2019 ijoon. All rights reserved.
//

import Foundation

public enum RendezvousPacketType: Int {
    case NONE = 0;
    case REGISTRATION_RENDEZVOUS_CLIENT_REQUEST = 10000; // SP private ip, SP private port
    case REGISTRATION_RENDEZVOUS_CLIENT_SUCCESS; // SP public ip, SP public port
    case REGISTRATION_RELAY_SERVER_REQUEST; // nullptr
    case REGISTRATION_RELAY_SERVER_SUCCESS; // nullptr
    case PING_REQUEST; // nullptr
    case PING_RESPONSE; // nullptr
    
    case CONNECTION_REQUEST; // TP public ip, TP public port
    
    case CONNECTION_ID_CREATED; // TP public ip, TP public port (RanS to SP)
    case CONNECTION_ID_RECEIVED; // TP public ip (SP to RanS)
    case CONNECTION_TARGET_INVALID; // TP public ip, TP public port
    case CONNECTION_FAILED; // nullptr
    
    // relay
    case RELAY_SERVICE_REQUEST; // SP pubilc ip, TP pubilc ip
    case RELAY_SERVICE_READY; // nullptr
    case RELAY_SERVER_INFORMATION; // RelS-ip, RelS-port, 1(SP) or 0(TP)
    case REGISTRATION_RELAY_PEER_REQUEST; // 1(SP) or 0(TP)
    case REGISTRATION_RELAY_PEER_SUCCESS; // nullptr
    case REGISTRATION_RELAY_PEER_FAILED; // nullptr
    case RELAY_SESSION_CREATED; // nullptr
    case RELAY_SESSION_CREATING_FAILED; // nullptr
    case RELAY_SESSION_INVALID; // nullptr
    
    case CONNECTION_RELAY_SERVICE_SUCCESS; // RelS-ip, RelS-port
    case CONNECTION_RELAY_SERVICE_FAILED; // nullptr
    
    // pub/pub or pri/pub
    case DIRECT_CONNECTION_AVAILABLE; // TP public ip, TP public port
    case DIRECT_CONNECTION_REQUEST; // nullptr
    case DIRECT_CONNECTION_RESPONSE; // nullptr
    
    // pub/pri
    case REVERSE_CONNECTION_READY; // nullptr
    case REVERSE_CONNECTION; // * SP public ip, SP public port
    case REVERSE_CONNECTION_REQUEST; // nullptr
    case REVERSE_CONNECTION_RESPONSE; // nullptr
    
    // pri/pri
    case UDP_HOLE_PUNCHING_AVAILABLE; // SP's public ip, public port, private ip, private port to TP (The opposite is also the case.)
    case UDP_HOLE_PUNCHING_REQUEST; // isPublic (1=true, 0=false)
    case UDP_HOLE_PUNCHING_RESPONSE; // isPublic (1=true, 0=false)
    
    case RENDEZVOUS_MSG_END;
}
