//
//  ServerManagerDelegate.swift
//  SCNet-Swift
//
//  Created by pbj on 2018. 8. 17..
//  Copyright © 2018년 ijoon. All rights reserved.
//

import Foundation

@objc public protocol ServerManagerDelegate {
    @objc optional func onAttaching(_ sessionIndex: Int32)
    @objc optional func onAttached(_ sessionIndex: Int32)
    @objc optional func onAttachFailed(_ sessionIndex: Int32)
    @objc optional func onDetached(_ sessionIndex: Int32)
}
