//
//  Date+milliseconds.swift
//  iOS SCNet_Swift
//
//  Created by pbj on 14/03/2019.
//  Copyright © 2019 ijoon. All rights reserved.
//

import Foundation

extension Date {
    var millisecondsSince1970:Int {
        return Int((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds:Int) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds / 1000))
    }
}
