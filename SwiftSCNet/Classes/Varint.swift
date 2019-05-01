//
//  Varint.swift
//  SCNet-Swift
//
//  Created by pbj on 2018. 8. 13..
//  Copyright © 2018년 ijoon. All rights reserved.
//

import Foundation

func encodeVarint(_ _value: Int32) -> [UInt8] {
    var value = _value
    var output: [UInt8] = []
    
    while(value > 127) {
        output.append(UInt8(value & 127) | 128)
        
        value >>= 7
    }
    output.append(UInt8(value & 127))
    return output
}

func decodeVarint(_ _input: [UInt8]) -> Int {
    var input = _input
    var ret: Int = 0
    for i in 0 ..< input.count {
        ret |= (Int(input[i]) & 127) << (7 * i)
        if (input[i] & 128 == 0) {
            break
        }
    }
    
    return ret
}
