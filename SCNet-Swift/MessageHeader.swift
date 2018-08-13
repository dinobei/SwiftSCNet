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

public struct MessageHeader {
    public var dataSize: Int
    public var packetType: Int
    public var cryptType: Int
};
