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
    public typealias ProtobufCallback = (Message)->Void
    public typealias RawByteCallback = (ArraySlice<UInt8>)->Void
    private var dict: Dictionary<String, Int32> // Protobuf Message name to packetType
    private var dictProtobufMessageType: Dictionary<Int32, Message.Type> // Packet type to protobuf message name
    private var dictProtobufCallback: Dictionary<Int32, ProtobufCallback?> // packetType to closure
    
    private var dictCallback: Dictionary<Int32, RawByteCallback?> // packetType to closure
    
    public static let sharedInstance = Registry()
    
    private init() {
        dict = Dictionary<String, Int32>()
        dictProtobufMessageType = Dictionary<Int32, Message.Type>()
        dictProtobufCallback = Dictionary<Int32, ProtobufCallback?>()
        dictCallback = Dictionary<Int32, RawByteCallback?>()
    }
    
    public func registRawBytePacket(packetType: Int32, callback: RawByteCallback?) throws {
        if dictCallback.keys.contains(packetType) {
            throw RegistError.AlreadyExistKey
        }
        dictCallback[packetType] = callback
    }
    
    public func registProtobufPacket(messageType: Message.Type, packetType: Int32, callback: ProtobufCallback?) throws {
        // regist packetType
        if dict.keys.contains(messageType.protoMessageName) {
            throw RegistError.AlreadyExistKey
        }
        dict[messageType.protoMessageName] = packetType
        
        // regist message type
        if dictProtobufMessageType.keys.contains(packetType) {
            throw RegistError.AlreadyExistKey
        }
        dictProtobufMessageType[packetType] = messageType
        
        // regist callback
        if dictProtobufCallback.keys.contains(packetType) {
            throw RegistError.AlreadyExistKey
        }
        dictProtobufCallback[packetType] = callback
    }
    
    public func getPacketType(_ message: Message) throws -> Int32 {
        let key = type(of: message).protoMessageName
        if let typeInt = dict[key] {
            return typeInt
        }

        throw RegistError.TryingToGetUnknownType
    }
    
    public func getMessageType(packetType: Int32) throws -> Message.Type {
        if let messageType = dictProtobufMessageType[packetType] {
            return messageType
        }
        
        throw RegistError.TryingToGetUnknownMessageType
    }
    
    public func getRawByteCallback(packetType: Int32) throws -> RawByteCallback? {
        if let callback = dictCallback[packetType] {
            return callback
        }
        
        throw GetRegistryError.NotExistKey
    }
    
    public func getProtobufCallback(packetType: Int32) throws -> ProtobufCallback? {
        let key = packetType
        if let callback = dictProtobufCallback[key] {
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
