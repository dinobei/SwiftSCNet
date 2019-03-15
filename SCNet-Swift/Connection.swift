//
//  Connection.swift
//  iOS SCNet_Swift
//
//  Created by pbj on 15/03/2019.
//  Copyright © 2019 ijoon. All rights reserved.
//

import Foundation

@objc public enum Connection: Int {
    case NONE
    case DIRECT_CONNECTION
    case REVERSE_CONNECTION
    case EQUAL_NAT
    case UDP_HOLE_PUNCHING
    case RELAY
    case PUBLIC
    case PRIVATE
}
