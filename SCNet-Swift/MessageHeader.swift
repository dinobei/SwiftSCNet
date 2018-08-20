//
//  MessageHeader.swift
//  SCNet-Swift
//
//  Created by pbj on 2018. 8. 13..
//  Copyright © 2018년 ijoon. All rights reserved.
//

import Foundation

let MAGIC_PACKET = "IJ"
let MAGIC_PACKET_LENGTH = 2

let HEADER_ELEMENTS = 5
let MAX_PACKET_HEADER_SIZE = (7 * HEADER_ELEMENTS)

@objc public class MessageHeader: NSObject {

    init(dataSize: Int, packetType: Int, messageType: Int, cryptType: Int, reserved: Int) {
        self.dataSize = dataSize
        self.packetType = packetType
        self.messageType = packetType
        self.cryptType = cryptType
        self.reserved = reserved
    }
    
    public var dataSize: Int = 0
    public var packetType: Int = 0
    public var messageType: Int = 0
    public var cryptType: Int = 0
    public var reserved: Int = 0
};
