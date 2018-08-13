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
    private var dict: Dictionary<String, Int32> // Key, TypeInt

    open static let sharedInstance = Registry()
    
    private init() {
        dict = Dictionary<String, Int32>()
    }
    
    public func regist(key: String, typeInt: Int32) throws {
        if dict.keys.contains(key) {
            throw RegistError.AlreadyExistKey
        }
        dict[key] = typeInt
    }
    
    public func getTypeInt(message: Message) throws -> Int32 {
        let key = type(of: message).protoMessageName
        if let typeInt = dict[key] {
            return typeInt
        }

        throw RegistError.TryingToGetUnknownType
    }
}

public enum RegistError: Error {
    case AlreadyExistKey
    case TryingToGetUnknownType
}
