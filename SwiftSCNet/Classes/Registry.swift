//
//  Registry.swift
//  SCNet-Swift
//
//  Created by pbj on 2018. 8. 13..
//  Copyright © 2018년 ijoon. All rights reserved.
//

import Foundation
import SwiftProtobuf

open class Registry {
    public typealias Callback = (Scnet_Header, Message)->Void
    private var dict: Dictionary<String, UInt32> // Protobuf Message name to packetType
    private var dictMessageType: Dictionary<UInt32, Message.Type> // Packet type to protobuf message name
    private var dictCallback: Dictionary<UInt32, Callback?> // packetType to closure
    
    public static let sharedInstance = Registry()
    
    private init() {
        dict = Dictionary<String, UInt32>()
        dictMessageType = Dictionary<UInt32, Message.Type>()
        dictCallback = Dictionary<UInt32, Callback?>()
    }
    
    public func registPacket(messageType: Message.Type, packetType: UInt32, callback: Callback?) throws {
        // regist packetType
        if dict.keys.contains(messageType.protoMessageName) {
            throw RegistError.AlreadyExistKey
        }
        dict[messageType.protoMessageName] = packetType
        
        // regist message type
        if dictMessageType.keys.contains(packetType) {
            throw RegistError.AlreadyExistKey
        }
        dictMessageType[packetType] = messageType
        
        // regist callback
        if dictCallback.keys.contains(packetType) {
            throw RegistError.AlreadyExistKey
        }
        dictCallback[packetType] = callback
    }
    
    public func getPacketType(_ message: Message) throws -> UInt32 {
        let key = type(of: message).protoMessageName
        if let typeInt = dict[key] {
            return typeInt
        }

        throw RegistError.TryingToGetUnknownType
    }
    
    public func getMessageType(packetType: UInt32) throws -> Message.Type {
        if let messageType = dictMessageType[packetType] {
            return messageType
        }
        
        throw RegistError.TryingToGetUnknownMessageType
    }
    
    public func getCallback(packetType: UInt32) throws -> Callback? {
        let key = packetType
        if let callback = dictCallback[key] {
            return callback
        }
        
        throw GetRegistryError.NotExistKey
    }
}

public enum RegistError: Error {
    case AlreadyExistKey
    case TryingToGetUnknownType
    case TryingToGetUnknownMessageName
    case TryingToGetUnknownMessageType
}

public enum GetRegistryError: Error {
    case NotExistKey
}
