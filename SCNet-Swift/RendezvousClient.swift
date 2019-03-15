//
//  RendezvousClient.swift
//  iOS SCNet_Swift
//
//  Created by pbj on 14/03/2019.
//  Copyright © 2019 ijoon. All rights reserved.
//

import Foundation
import SwiftSocket

open class RendezvousClient {
    var rendezvousServerIP: String!
    var rendezvousServerPort: Int!
    
    var rendezvousSessionMap: [Int : RendezvousSession]
    var kcpPeerMap: [String : KCPPeer]
    
    var udpClient: UDPClient
    
    var delegate: RendezvousClientDelegate
    var isCallConnCallback: Bool
    
    public required init(rendezvousServerIP: String, port: Int, delegate: RendezvousClientDelegate) {
        self.rendezvousServerIP = rendezvousServerIP
        self.rendezvousServerPort = port
        self.delegate = delegate
        self.isCallConnCallback = false
        
        rendezvousSessionMap = [Int : RendezvousSession]()
        kcpPeerMap = [String : KCPPeer]()
        
        udpClient = UDPClient()
    }
    
    func getKcpPeer(ip: String, port: Int) -> KCPPeer {
        let kcpPeer = kcpPeerMap["\(ip):\(port)"]
        if let kcpPeer = kcpPeer {
            return kcpPeer
        }
        
        let newKcpPeer = KCPPeer(udpClient, ip: ip, port: port)
        kcpPeerMap["\(ip):\(port)"] = newKcpPeer
        
        return newKcpPeer
    }
    
    public func start() {
        let registerDQ = DispatchQueue.init(label: "registerDQ")
        
        let loopInterval: Int = 5 * 1000
        let pingInterval: Int = 30 * 1000
        registerDQ.async {
            let rendezvousKcpPeer = self.getKcpPeer(ip: self.rendezvousServerIP, port: self.rendezvousServerPort)

            var address = "0.0.0.0"
            if let _address = getWiFiAddress() {
                address = _address
            }
            else if let _address = UIDevice.current.ipAddress() {
                address = _address
            }
            
            print("local Address: \(address):\(rendezvousKcpPeer.udpClient.getLocalPort())")
            
            let data = "\(address) \(rendezvousKcpPeer.udpClient.getLocalPort()) ios"
            if !rendezvousKcpPeer.send(connectionID: 0, packetType: RendezvousPacketType.REGISTRATION_RENDEZVOUS_CLIENT_REQUEST, data: data) {
                NSLog("send failed")
            }
            var lastRegistrationTime = Date().millisecondsSince1970
            
            while(true) {
                isleep(millisecond: loopInterval)
                
                let current = Date().millisecondsSince1970
                
                if lastRegistrationTime + pingInterval < current {
                    lastRegistrationTime = current
                    if !rendezvousKcpPeer.send(connectionID: 0, packetType: RendezvousPacketType.REGISTRATION_RENDEZVOUS_CLIENT_REQUEST, data: data) {
                        NSLog("send failed")
                    }
                }
                
            }
        }
        
        let rawRecvDQ = DispatchQueue.init(label: "rawRecvDQ")
        rawRecvDQ.async {
            while(true) {
                let (byteArrayOptional, ip, port) = self.udpClient.recv(3000)
                guard let byteArray = byteArrayOptional else {
                    print("recv timeout")
                    continue
                }

                let kcpPeer = self.getKcpPeer(ip: ip, port: port)
                let _ = kcpPeer.kcp.input(data: Data(byteArray))
            }
        }
        
        let recvDQ = DispatchQueue.init(label: "recvDQ")
        recvDQ.async {
            let minInterval = 10
            while(true) {
                let current = Date().millisecondsSince1970

                for kcpPeer in self.kcpPeerMap.values {
                    let data = kcpPeer.kcp.recv(dataSize: MAX_PACKET_SIZE)

                    kcpPeer.kcp.update(current: UInt32(truncating: NSNumber(value: current)))
                    if let data = data {
                        let byteArray: [UInt8] = Array(data)
                        self.callback(kcpPeer, buffer: byteArray, size: byteArray.count)
                    }
                }

                isleep(millisecond: minInterval)
            }
        }
        
        
    }
    
    func callback(_ kcpPeer: KCPPeer, buffer: [UInt8], size: Int) {
        guard buffer[0] == Array(MAGIC_PACKET.utf8)[0],
            buffer[1] == Array(MAGIC_PACKET.utf8)[1] else {
                return
        }
        
        var receivedHeaderComponent = 0
        
        var headerBuffer: [[UInt8]] = []
        for _ in 0 ..< HEADER_ELEMENTS {
            headerBuffer.append([])
        }
        
        var cursor = MAGIC_PACKET_LENGTH
        var singleItemSize = 0
        while true {
            guard cursor < size else {
                return
            }
            
            let data = buffer[cursor]
            cursor += 1
            headerBuffer[receivedHeaderComponent].append(data)
            
            if (data&0xFF) > 127 {
                singleItemSize += 1
                guard singleItemSize <= 7 else {
                    return
                }
                continue
            }
            
            singleItemSize = 0
            receivedHeaderComponent += 1
            
            if receivedHeaderComponent >= HEADER_ELEMENTS {
                break
            }
        }
        
        // get MessageHeader
        let messageHeader = MessageHeader(dataSize: decodeVarint(headerBuffer[0]),
                                          packetType: decodeVarint(headerBuffer[1]),
                                          messageType: decodeVarint(headerBuffer[2]),
                                          cryptType: decodeVarint(headerBuffer[3]),
                                          connectionID: decodeVarint(headerBuffer[4]))
        
        var data = [UInt8]()
        if cursor < size {
            data = Array(buffer[cursor...size-1])
        }
        
        print("messageHeader: \(messageHeader.dataSize), \(messageHeader.packetType), \(messageHeader.messageType), \(messageHeader.cryptType), \(messageHeader.connectionID)")
        
        kcpPeer.lastPing = Date().millisecondsSince1970
        
        guard let messageType = MESSAGE_TYPE.init(rawValue: Int32(messageHeader.messageType)) else {
            return
        }
        
        switch messageType {
        case .PROTOBUF:
            ()
            // callback to user, MAKE message using (messageHeader, data)
            return
        case .RAWBYTE:
            let rendezvousPacketType = RendezvousPacketType.init(rawValue: messageHeader.packetType)
            guard rendezvousPacketType == nil else {
                break
            }
            
            // callback to user, (messageHeader.packetType, data)
            return
        default:
            ()
        }
        
        guard messageType == .RAWBYTE else {
            NSLog("currently only support message type RAWBYTE for Rendezvous message")
            return
        }
        
        guard let rendezvousPacketType = RendezvousPacketType.init(rawValue: messageHeader.packetType) else {
            NSLog("Undefined rendezvous packet type (\(messageHeader.packetType))")
            return
        }
        let body = String(bytes: data, encoding: .utf8)
        
        switch rendezvousPacketType {
        case .REGISTRATION_RENDEZVOUS_CLIENT_SUCCESS:
            NSLog("received REGISTRATION_RENDEZVOUS_CLIENT_SUCCESS")

            guard   let bodyArray = body?.components(separatedBy: " "),
                    bodyArray.count == 2 else {
                NSLog("invalid parameters")
                return
            }
            
            let myPublicIP = bodyArray[0]
            let myPublicPort = bodyArray[1]
            NSLog("[REGISTRATION_RENDEZVOUS_CLIENT_SUCCESS] MyPublicAddress=\(myPublicIP):\(myPublicPort)")
            
            if !isCallConnCallback {
                isCallConnCallback = true
                delegate.onConnectedToRendezvousServer?(myPublicIP, myPublicPort)
            }

        case .CONNECTION_TARGET_INVALID:
            NSLog("received CONNECTION_TARGET_INVALID")
            guard   let bodyArray = body?.components(separatedBy: " "),
                    bodyArray.count == 2 else {
                NSLog("invalid parameters")
                return
            }
            
            guard let targetPort = Int(bodyArray[1]) else {
                return
            }
            delegate.onTargetInvalid?(bodyArray[0], targetPort)
        case .CONNECTION_ID_CREATED:
            NSLog("received CONNECTION_ID_CREATED")
            guard   let bodyArray = body?.components(separatedBy: " "),
                    bodyArray.count == 2 else {
                NSLog("invalid parameters")
                return
            }
            
            guard let targetPort = Int(bodyArray[1]) else {
                return
            }
            let rendezvousSession = getRendezvousSessionSafety(messageHeader: messageHeader)
            delegate.onConnectionIDCreated?(rendezvousSession, bodyArray[0], targetPort)
            
            kcpPeer.send(connectionID: messageHeader.connectionID, packetType: .CONNECTION_ID_RECEIVED, data: bodyArray[0])
        case .DIRECT_CONNECTION_AVAILABLE:
            NSLog("received DIRECT_CONNECTION_AVAILABLE")
            guard   let bodyArray = body?.components(separatedBy: " "),
                    bodyArray.count == 2 else {
                NSLog("invalid parameters")
                return
            }

            delegate.onConnecting?(messageHeader.connectionID)

            guard let port = Int(bodyArray[1]) else {
                return
            }
            let targetKcpPeer = getKcpPeer(ip: bodyArray[0], port: port)
            targetKcpPeer.send(connectionID: messageHeader.connectionID, packetType: .DIRECT_CONNECTION_REQUEST, data: nil)
        case .DIRECT_CONNECTION_REQUEST:
            NSLog("received DIRECT_CONNECTION_REQUEST")

            let rendezvousSession = getRendezvousSessionSafety(messageHeader: messageHeader)
            let isConnected = rendezvousSession.isConnected()
            
            rendezvousSession.publicKCPPeer = kcpPeer
            
            NSLog("directly connected from \(kcpPeer.getKey())")
            
            if !isConnected {
                delegate.onConnected?(rendezvousSession, Connection.DIRECT_CONNECTION)
            }
            else {
                delegate.onConnectionUpdate?(rendezvousSession, Connection.DIRECT_CONNECTION)
            }
            
            kcpPeer.send(connectionID: messageHeader.connectionID, packetType: .DIRECT_CONNECTION_RESPONSE, data: nil)
        case .DIRECT_CONNECTION_RESPONSE:
            NSLog("received DIRECT_CONNECTION_RESPONSE")
            
            let rendezvousSession = getRendezvousSessionSafety(messageHeader: messageHeader)
            let isConnected = rendezvousSession.isConnected()
            
            rendezvousSession.publicKCPPeer = kcpPeer
            
            NSLog("directly connected from \(kcpPeer.getKey())")
            
            if !isConnected {
                delegate.onConnected?(rendezvousSession, Connection.DIRECT_CONNECTION)
            }
            else {
                delegate.onConnectionUpdate?(rendezvousSession, Connection.DIRECT_CONNECTION)
            }
        case .REVERSE_CONNECTION_READY:
            NSLog("received REVERSE_CONNECTION_READY")
            let rendezvousSession = getRendezvousSessionSafety(messageHeader: messageHeader)
            if !rendezvousSession.isConnected() {
                delegate.onConnecting?(messageHeader.connectionID)
            }
        case .REVERSE_CONNECTION:
            NSLog("received REVERSE_CONNECTION")
            
            guard   let bodyArray = body?.components(separatedBy: " "),
                    bodyArray.count == 2 else {
                NSLog("invalid parameters")
                return
            }

            
            guard let port = Int(bodyArray[1]) else {
                return
            }
            let sourceKcpPeer = getKcpPeer(ip: bodyArray[0], port: port)
            if !sourceKcpPeer.send(connectionID: messageHeader.connectionID, packetType: .REVERSE_CONNECTION_REQUEST, data: nil) {
                NSLog("[REVERSE_CONNECTION] send failed")
            }
        case .REVERSE_CONNECTION_REQUEST:
            NSLog("received REVERSE_CONNECTION_REQUEST")

            if !kcpPeer.send(connectionID: messageHeader.connectionID, packetType: .REVERSE_CONNECTION_RESPONSE, data: nil) {
                NSLog("[REVERSE_CONNECTION_REQUEST] send failed")
            }

            let rendezvousSession = getRendezvousSessionSafety(messageHeader: messageHeader)
            let isConnected = rendezvousSession.isConnected()
            
            rendezvousSession.publicKCPPeer = kcpPeer;
            
            NSLog("reversely connected from \(kcpPeer.getKey())");

            if !isConnected {
                delegate.onConnected?(rendezvousSession, .REVERSE_CONNECTION)
            }
            else {
                delegate.onConnectionUpdate?(rendezvousSession, .REVERSE_CONNECTION)
            }
        case .REVERSE_CONNECTION_RESPONSE:
            NSLog("received REVERSE_CONNECTION_RESPONSE")
            
            let rendezvousSession = getRendezvousSessionSafety(messageHeader: messageHeader)
            let isConnected = rendezvousSession.isConnected()
            
            rendezvousSession.publicKCPPeer = kcpPeer;
            
            NSLog("reversely connected from \(kcpPeer.getKey())");

            if !isConnected {
                delegate.onConnected?(rendezvousSession, .REVERSE_CONNECTION)
            }
            else {
                delegate.onConnectionUpdate?(rendezvousSession, .REVERSE_CONNECTION)
            }
        case .UDP_HOLE_PUNCHING_AVAILABLE:
            NSLog("received UDP_HOLE_PUNCHING_AVAILABLE");
            
            guard   let bodyArray = body?.components(separatedBy: " "),
                    bodyArray.count == 4 else {
                NSLog("invalid parameters")
                return
            }
            
            let rendezvousSession = getRendezvousSessionSafety(messageHeader: messageHeader)
            if !rendezvousSession.isConnected() {
                delegate.onConnecting?(messageHeader.connectionID)
            }
            
            guard let publicPort = Int(bodyArray[1]) else {
                return
            }
            let publicKcpPeer = getKcpPeer(ip: bodyArray[0], port: publicPort)
            if !publicKcpPeer.send(connectionID: messageHeader.connectionID, packetType: .UDP_HOLE_PUNCHING_REQUEST, data: "1") {
                NSLog("[UDP_HOLE_PUNCHING_AVAILABLE] send failed")
            }
            
            guard let privatePort = Int(bodyArray[3]) else {
                return
            }
            let privateKcpPeer = getKcpPeer(ip: bodyArray[2], port: privatePort)
            if !privateKcpPeer.send(connectionID: messageHeader.connectionID, packetType: .UDP_HOLE_PUNCHING_REQUEST, data: "0") {
                NSLog("[UDP_HOLE_PUNCHING_AVAILABLE] send failed")
            }
        case .UDP_HOLE_PUNCHING_REQUEST:
            NSLog("received UDP_HOLE_PUNCHING_REQUEST")

            guard   let bodyArray = body?.components(separatedBy: " "),
                    bodyArray.count == 1 else {
                NSLog("invalid parameters")
                return
            }
            
            if !kcpPeer.send(connectionID: messageHeader.connectionID, packetType: .UDP_HOLE_PUNCHING_RESPONSE, data: bodyArray[0]) {
                NSLog("[UDP_HOLE_PUNCHING_REQUEST] send failed")
            }
        case .UDP_HOLE_PUNCHING_RESPONSE:
            NSLog("received UDP_HOLE_PUNCHING_RESPONSE")
            
            guard   let bodyArray = body?.components(separatedBy: " "),
                    bodyArray.count == 1 else {
                NSLog("invalid parameters")
                return
            }
            
            guard let isPublicInt = Int(bodyArray[0]) else {
                return
            }
            let isPublic = isPublicInt == 1;
            
            NSLog("received UDP_HOLE_PUNCHING_RESPONSE, isPublic=\(isPublic)");
            
            let rendezvousSession = getRendezvousSessionSafety(messageHeader: messageHeader)
            let isConnected = rendezvousSession.isConnected()

            var connection: Connection = .NONE
            if isPublic {
                if rendezvousSession.publicKCPPeer == nil {
                    rendezvousSession.publicKCPPeer = kcpPeer
                    connection = .UDP_HOLE_PUNCHING
                    NSLog("connected by udp hole punching from \(kcpPeer.getKey())")
                }
            }
            else {
                if rendezvousSession.privateKCPPeer == nil {
                    rendezvousSession.privateKCPPeer = kcpPeer
                    connection = .EQUAL_NAT
                    NSLog("connected under equal NAT from \(kcpPeer.getKey())");
                }
            }

            if connection != .NONE {
                if !isConnected {
                    delegate.onConnected?(rendezvousSession, connection)
                }
                else {
                    delegate.onConnectionUpdate?(rendezvousSession, connection)
                }
            }
        case .RELAY_SERVER_INFORMATION:
            NSLog("received RELAY_SERVER_INFORMATION")

            guard   let bodyArray = body?.components(separatedBy: " "),
                    bodyArray.count == 3 else {
                NSLog("invalid parameters")
                return
            }
            
            delegate.onConnecting?(messageHeader.connectionID)

            NSLog("relay server: \(bodyArray[0]), \(bodyArray[1])")

            guard let relayServerPort = Int(bodyArray[1]) else {
                return
            }
            let relayKcpPeer = getKcpPeer(ip: bodyArray[0], port: relayServerPort)
            
            if !relayKcpPeer.send(connectionID: messageHeader.connectionID, packetType: .REGISTRATION_RELAY_PEER_REQUEST, data: bodyArray[2]) {
                NSLog("[RELAY_SERVER_INFORMATION] send failed")
            }
        case .CONNECTION_RELAY_SERVICE_SUCCESS:
            NSLog("received CONNECTION_RELAY_SERVICE_SUCCESS")
            
            guard   let bodyArray = body?.components(separatedBy: " "),
                bodyArray.count == 2 else {
                    NSLog("invalid parameters")
                    return
            }

            let rendezvousSession = getRendezvousSessionSafety(messageHeader: messageHeader)
            
            guard let relayServerPort = Int(bodyArray[1]) else {
                return
            }
            rendezvousSession.relayKCPPeer = getKcpPeer(ip: bodyArray[0], port: relayServerPort)
            NSLog("connected by a relay from \(bodyArray[0]):\(bodyArray[1])")
            delegate.onConnected?(rendezvousSession, .RELAY)
        case .CONNECTION_RELAY_SERVICE_FAILED:
            NSLog("received CONNECTION_RELAY_SERVICE_FAILED")
        case .REGISTRATION_RELAY_PEER_SUCCESS:
            NSLog("received REGISTRATION_RELAY_PEER_SUCCESS")
        case .REGISTRATION_RELAY_PEER_FAILED:
            NSLog("received REGISTRATION_RELAY_PEER_FAILED")
        case .PING_REQUEST:
            NSLog("received PING_REQUEST from \(kcpPeer.getKey())")
            kcpPeer.send(connectionID: 0, packetType: .PING_RESPONSE, data: nil)
        case .PING_RESPONSE:
            NSLog("received PING_RESPONSE")
        default:
            NSLog("rendezvous packet type process not defined, \(rendezvousPacketType)")
        }
        
    }

    func getRendezvousSessionSafety(messageHeader: MessageHeader) -> RendezvousSession {
        guard let rendezvousSession = rendezvousSessionMap[messageHeader.connectionID] else {
            let rendezvousSession = RendezvousSession(connectionID: messageHeader.connectionID)
            if messageHeader.connectionID != 0 {
                rendezvousSessionMap[messageHeader.connectionID] = rendezvousSession
            }
            return rendezvousSession
        }
        
        return rendezvousSession
    }
    
    public func connect(ip: String, port: String) {
        let rendezvousKcpPeer = getKcpPeer(ip: rendezvousServerIP, port: rendezvousServerPort)
        if !rendezvousKcpPeer.send(connectionID: 0, packetType: .CONNECTION_REQUEST, data: "\(ip) \(port)") {
            NSLog("send failed")
        }
    }
}

func isleep(millisecond:Int) -> Void {
    usleep(useconds_t((millisecond << 10) - (millisecond << 4) - (millisecond << 3)))
}

