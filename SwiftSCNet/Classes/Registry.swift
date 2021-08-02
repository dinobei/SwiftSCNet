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
    public typealias Callback = (Header, Message)->Void
    public typealias EventCallback = ()->Void
    private var dictPbMessage: Dictionary<String, Message.Type> // Packet type (string) to protobuf message name
    private var dictCallback: Dictionary<String, Callback?> // packetType to closure
    
    public static let sharedInstance = Registry()
    
    private init() {
        dictPbMessage = Dictionary<String, Message.Type>()
        dictCallback = Dictionary<String, Callback?>()
    }
    
    public func registPacket(messageType: Message.Type, callback: Callback?) throws {
        // regist message type
        let packetType = messageType.protoMessageName.lowercased()
        if dictPbMessage.keys.contains(packetType) {
            throw RegistError.AlreadyExistKey
        }
        dictPbMessage[packetType] = messageType
        
        // regist callback
        if callback != nil {
            if dictCallback.keys.contains(packetType) {
                throw RegistError.AlreadyExistKey
            }
            dictCallback[packetType] = callback
        }
    }
    
    public func getPacketType(_ message: Message) throws -> String {
        let packetType = type(of: message).protoMessageName.lowercased()
        return packetType
    }
    
    public func getMessageType(packetType: String) throws -> Message.Type {
        if let messageType = dictPbMessage[packetType] {
            return messageType
        }
        
        throw RegistError.TryingToGetUnknownMessageType
    }
    
    public func getCallback(packetType: String) throws -> Callback? {
        if let callback = dictCallback[packetType] {
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
