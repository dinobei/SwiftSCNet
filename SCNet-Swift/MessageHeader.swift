//
//  MessageHeader.swift
//  SCNet-Swift
//
//  Created by pbj on 2018. 8. 13..
//  Copyright © 2018년 ijoon. All rights reserved.
//

import Foundation

let HEADER_ELEMENTS = 3
let MAX_PACKET_HEADER_SIZE = (7 * HEADER_ELEMENTS)

@objc public class MessageHeader: NSObject {

    init(dataSize: Int, packetType: Int, cryptType: Int) {
        self.dataSize = dataSize
        self.packetType = packetType
        self.cryptType = cryptType
    }
    
    public var dataSize: Int = 0
    public var packetType: Int = 0
    public var cryptType: Int = 0
};
