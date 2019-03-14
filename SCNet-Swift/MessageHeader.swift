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

let MAX_PACKET_SIZE = 655350
let MAX_WAIT_SEND = 300

@objc public class MessageHeader: NSObject {

    init(dataSize: Int, packetType: Int, messageType: Int, cryptType: Int, connectionID: Int) {
        self.dataSize = dataSize
        self.packetType = packetType
        self.messageType = messageType
        self.cryptType = cryptType
        self.connectionID = connectionID
    }
    
    public var dataSize: Int = 0
    public var packetType: Int = 0
    public var messageType: Int = 0
    public var cryptType: Int = 0
    public var connectionID: Int = 0
};

public enum MESSAGE_TYPE: Int32 {
    case PROTOBUF = 0;
    case RAWBYTE = 1;
    case RAWBYTE_RELAY = 2;
    case PROTOBF_RELAY = 3;
}
