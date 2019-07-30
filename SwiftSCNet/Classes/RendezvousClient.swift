//
//  RendezvousClient.swift
//  iOS SCNet_Swift
//
//  Created by pbj on 14/03/2019.
//  Copyright © 2019 ijoon. All rights reserved.
//

import Foundation
import SwiftSocket
import SwiftProtobuf

let kcpPeerSyncDQ = DispatchQueue.init(label: "kcp peer sync dq")
let rendezvousSessionSyncDQ = DispatchQueue.init(label: "rendezvous session sync dq")

open class RendezvousClient {
    var rendezvousServerIP: String!
    var rendezvousServerPort: Int!
    
    var rendezvousSessionMap: [Int : RendezvousSession]
    var kcpPeerMap: [String : KCPPeer]
    
    var udpClient: UDPClient
    
    var delegate: RendezvousClientDelegate
    var isCallConnCallback: Bool
    
    let registry = Registry.sharedInstance
    
    var isInterrupted: Bool
    
    public required init(rendezvousServerIP: String, port: Int, delegate: RendezvousClientDelegate) {
        self.rendezvousServerIP = rendezvousServerIP
        self.rendezvousServerPort = port
        self.delegate = delegate
        self.isCallConnCallback = false
        
        rendezvousSessionMap = [Int : RendezvousSession]()
        kcpPeerMap = [String : KCPPeer]()
        
        udpClient = UDPClient()
        
        isInterrupted = true
    }
    
    deinit {
        isInterrupted = true
        udpClient.close()
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
    
    public func start() -> Bool {
        guard isInterrupted else {
            NSLog("already started")
            return false
        }
        isInterrupted = false
        
        let registerDQ = DispatchQueue.init(label: "registerDQ")
        
        let rendezvousKcpPeer = self.getKcpPeer(ip: self.rendezvousServerIP, port: self.rendezvousServerPort)
        let loopInterval: Int = 5 * 1000
        let pingInterval: Int64 = 30 * 1000
        let timeout: Int64 = 60 * 1000
        registerDQ.async {
            #if os(iOS) || os(watchOS) || os(tvOS)
            let optionalAddr = UIDevice.current.ipAddress()
            #elseif os(OSX)
            let optionalAddr = Host.current().ipAddress()
            #else
            assert(false, "Unknown device")
            #endif
            
            var address = "0.0.0.0"
            if let _address = getWiFiAddress() {
                address = _address
            }
            else if let _address = optionalAddr {
                address = _address
            }
            
            print("local Address: \(address):\(rendezvousKcpPeer.udpClient.getLocalPort())")
            let data = "\(address) \(rendezvousKcpPeer.udpClient.getLocalPort()) \(getSystemUUID())"
            var lastRegistrationTime: Int64 = 0

            while(!self.isInterrupted) {
                let current = Date().millisecondsSince1970
                
                if lastRegistrationTime + pingInterval < current {
                    lastRegistrationTime = current
                    if !rendezvousKcpPeer.send(connectionID: 0, packetType: RendezvousPacketType.REGISTRATION_RENDEZVOUS_CLIENT_REQUEST, data: data) {
                        NSLog("send failed")
                    }
                }

                isleep(millisecond: loopInterval)
                
                kcpPeerSyncDQ.sync {
                    for (key, kcpPeer) in self.kcpPeerMap.reversed() {
                        if kcpPeer.lastPing + timeout < current {
                            self.kcpPeerMap.removeValue(forKey: key)
                        }
                        else if kcpPeer.lastPing + pingInterval < current {
                            DispatchQueue.main.async {
                                if !kcpPeer.send(connectionID: 0, packetType: RendezvousPacketType.PING_REQUEST, data: nil) {
                                    NSLog("send failed")
                                }
                            }
                        }
                    }
                }

                rendezvousSessionSyncDQ.sync {
                    for (key, rendezvousSession) in self.rendezvousSessionMap {
                        if let relayKcpPeer = rendezvousSession.relayKCPPeer {
                            if relayKcpPeer.lastPing + timeout < current {
                                NSLog("relay peer removed, \(relayKcpPeer.lastPing)")
                                rendezvousSession.relayKCPPeer = nil
                                self.delegate.onConnectionRemoved?(rendezvousSession, Connection.RELAY)
                            }
                        }
                        if let publicKcpPeer = rendezvousSession.publicKCPPeer {
                            if publicKcpPeer.lastPing + timeout < current {
                                NSLog("public peer removed, \(publicKcpPeer.lastPing)")
                                rendezvousSession.publicKCPPeer = nil
                                self.delegate.onConnectionRemoved?(rendezvousSession, Connection.PUBLIC)
                            }
                        }
                        if let privateKcpPeer = rendezvousSession.privateKCPPeer {
                            if privateKcpPeer.lastPing + timeout < current {
                                NSLog("private peer removed, \(privateKcpPeer.lastPing)")
                                rendezvousSession.privateKCPPeer = nil
                                self.delegate.onConnectionRemoved?(rendezvousSession, Connection.PRIVATE)
                            }
                        }
                        
                        if !rendezvousSession.isConnected() {
                            let connectionID = rendezvousSession.connectionID
                            self.rendezvousSessionMap.removeValue(forKey: key)
                            self.delegate.onDisconnected?(connectionID)
                            NSLog("Disconnected, connectionID=\(connectionID)")
                        }
                    }
                }
            }
            print("registerDQ finished")
        }
        
        let rawRecvDQ = DispatchQueue.init(label: "rawRecvDQ")
        rawRecvDQ.async {
            while(!self.isInterrupted) {
                let (byteArrayOptional, ip, port) = self.udpClient.recv(1500)
                guard let byteArray = byteArrayOptional else {
                    print("recv timeout")
                    continue
                }

                kcpPeerSyncDQ.sync {
                    let kcpPeer = self.getKcpPeer(ip: ip, port: port)
                    kcpPeer.lock.lock()
                    let _ = kcpPeer.kcp.input(data: Data(byteArray))
                    kcpPeer.lock.unlock()
                }
            }
            print("rawRecvDQ finished")
        }
        
        let recvDQ = DispatchQueue.init(label: "recvDQ")
        recvDQ.async {
            let minInterval = 10
            while(!self.isInterrupted) {
                let current = Date().millisecondsSince1970

                kcpPeerSyncDQ.sync {
                    for kcpPeer in self.kcpPeerMap.values {
                        kcpPeer.lock.lock()
                        let data = kcpPeer.kcp.recv()
                        kcpPeer.kcp.update(millisec: UInt32(current & 0x7FFFFFFF))
                        kcpPeer.lock.unlock()
                        
                        if let data = data {
                            let byteArray = [UInt8](data)
                            self.callback(kcpPeer, buffer: byteArray, size: byteArray.count)
                        }
                    }
                }

                isleep(millisecond: minInterval)
            }
            print("recvDQ finished")
        }
        
        return true
    }
    
    public func stop() -> Bool {
        guard !isInterrupted else {
            NSLog("already stopped")
            return false
        }
        isCallConnCallback = false
        isInterrupted = true
        udpClient.close()
        udpClient = UDPClient()
        
        kcpPeerSyncDQ.sync {
            self.kcpPeerMap.removeAll()
        }
        
        rendezvousSessionSyncDQ.sync {
            self.rendezvousSessionMap.removeAll()
        }
        return true
    }
    
    func callback(_ kcpPeer: KCPPeer, buffer: [UInt8], size: Int) {
        guard buffer[0] == MAGIC_PACKET[0],
            buffer[1] == MAGIC_PACKET[1] else {
                return
        }
        
        var receivedHeaderComponent = 0
        
        var headerBuffer: [[UInt8]] = []
        headerBuffer.reserveCapacity(HEADER_ELEMENTS)
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
        
        var data = ArraySlice<UInt8>()
        if cursor < size {
            data = buffer[cursor...size-1]
        }
        
        kcpPeer.lastPing = Date().millisecondsSince1970
        
        guard let messageType = MESSAGE_TYPE.init(rawValue: Int32(messageHeader.messageType)) else {
            return
        }
        
        switch messageType {
        case .PROTOBUF:
            do {
                let messageType = try self.registry.getMessageType(packetType: Int32(messageHeader.packetType))
                let message = try messageType.init(serializedData: Data(data))
                let callback = try self.registry.getProtobufCallback(packetType: Int32(messageHeader.packetType))
                callback?(message)
            }
            catch {
            }
            return
        case .RAWBYTE:
            guard messageHeader.packetType < RendezvousPacketType.REGISTRATION_RENDEZVOUS_CLIENT_REQUEST.rawValue else {
                    break
            }
            
            do {
                try self.registry.getRawByteCallback(packetType: Int32(messageHeader.packetType))?(data)
            }
            catch {
            }
            
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
        var _rendezvousSession: RendezvousSession?
        rendezvousSessionSyncDQ.sync {
            _rendezvousSession = rendezvousSessionMap[messageHeader.connectionID]
        }
        guard let rendezvousSession = _rendezvousSession else {
            let rendezvousSession = RendezvousSession(connectionID: messageHeader.connectionID)
            if messageHeader.connectionID != 0 {
                rendezvousSessionSyncDQ.sync {
                    rendezvousSessionMap[messageHeader.connectionID] = rendezvousSession
                }
            }
            return rendezvousSession
        }
        
        return rendezvousSession
    }
    
    public func connect(ip: String, port: String) {
        kcpPeerSyncDQ.sync {
            let rendezvousKcpPeer = getKcpPeer(ip: rendezvousServerIP, port: rendezvousServerPort)
            if !rendezvousKcpPeer.send(connectionID: 0, packetType: .CONNECTION_REQUEST, data: "\(ip) \(port)") {
                NSLog("send failed")
            }
        }
    }
    
    public func send(message: Message) {
        kcpPeerSyncDQ.sync {
            let rendezvousKcpPeer = getKcpPeer(ip: rendezvousServerIP, port: rendezvousServerPort)

            do {
                if try !rendezvousKcpPeer.send(connectionID: 0, request: message) {
                    NSLog("send failed")
                }
            }
            catch {
                print("error : \(error)")
            }
        }
    }
}

func isleep(millisecond:Int) -> Void {
    usleep(useconds_t((millisecond << 10) - (millisecond << 4) - (millisecond << 3)))
}

#if os(OSX)
func getSystemUUID() -> String {
    let dev = IOServiceMatching("IOPlatformExpertDevice")
    let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, dev)
    let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)
    IOObjectRelease(platformExpert)
    let ser = serialNumberAsCFString?.takeUnretainedValue() ?? nil
    if let result = ser as? String {
        return result
    }
    return "unknown_macos_uuid"
}
#elseif os(iOS) || os(watchOS) || os(tvOS)
func getSystemUUID() -> String {
    return UIDevice.current.identifierForVendor!.uuidString
}
#endif
