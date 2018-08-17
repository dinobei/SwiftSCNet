//
//  ServerManager.swift
//  SCNet-Swift
//
//  Created by pbj on 2018. 8. 17..
//  Copyright © 2018년 ijoon. All rights reserved.
//

import Foundation
import SwiftProtobuf

open class ServerManager: NSObject {
    let MAX_CONNECTION = 21
    private var dict: Dictionary<Int32, ServerSession>
    
    open static let sharedInstance = ServerManager()
    
    private override init() {
        dict = Dictionary<Int32, ServerSession>()
    }
    
    open func attach(ip: String, port: Int32, delegate: ServerManagerDelegate, queue: DispatchQueue) throws -> Int32 {
        for i in Int32(0) ..< Int32(MAX_CONNECTION) {
            if !dict.keys.contains(i) {
                let serverSession = ServerSession(sessionIndex: i, ip: ip, port: port, delegate: delegate)
                
                queue.async {
                    serverSession.attach(timeout: 1000)
                }
                
                dict[i] = serverSession
                return i
            }
        }
        
        throw ServerManagerError.maximumServerSession
    }
    
    open func request(sessionIndex: Int32, message: Message) -> Bool {
        guard dict.keys.contains(sessionIndex) else {
            return false
        }
        
        dict[sessionIndex]?.control(req: message)
        return true
    }
    
    open func detach(sessionIndex: Int32) {
        guard dict.keys.contains(sessionIndex) else {
            return
        }
        
        dict[sessionIndex]?.detach()
        dict.removeValue(forKey: sessionIndex)
    }
    
    open func detachAll() {
        for serverSession in dict.values {
            serverSession.detach()
        }
        dict.removeAll()
    }
}

enum ServerManagerError: Error {
    case maximumServerSession
}
