//
//  ClientManagerDelegate.swift
//  SCNet-Swift
//
//  Created by pbj on 2018. 8. 15..
//  Copyright © 2018년 ijoon. All rights reserved.
//

import Foundation

@objc public protocol ClientDelegate {
    @objc optional func onAttaching()
    @objc optional func onAttached()
    @objc optional func onTimedOut()
    @objc optional func onAttachFailed()
    @objc optional func onDetached()
}
