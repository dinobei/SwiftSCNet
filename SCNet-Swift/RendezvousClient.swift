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
    
    let rendezvousSession: [Int : RendezvousSession]
    var kcpPeerMap: [String : KCPPeer]
    
    var udpClient: UDPClient
    
    public required init(rendezvousServerIP: String, port: Int) {
        self.rendezvousServerIP = rendezvousServerIP
        self.rendezvousServerPort = port
        
        rendezvousSession = [Int : RendezvousSession]()
        kcpPeerMap = [String : KCPPeer]()
        
        udpClient = UDPClient()
    }
    
    func getKcpPeer(ip: String, port: Int) -> KCPPeer {
        let kcpPeer = kcpPeerMap["\(ip):\(port)"]
        if let kcpPeer = kcpPeer {
            return kcpPeer
        }
        
        let newKcpPeer = KCPPeer(udpClient, ip: ip, port: port);
        kcpPeerMap["\(ip):\(port)"] = newKcpPeer
        
        return newKcpPeer
    }
    
    public func start() {
        let registerDQ = DispatchQueue.init(label: "registerDQ")
        
        let loopInterval: Int = 5 * 1000
        let pingInterval: Int = 30 * 1000;
        registerDQ.async {
            let rendezvousKcpPeer = self.getKcpPeer(ip: self.rendezvousServerIP, port: self.rendezvousServerPort)
            
            print("local port \(rendezvousKcpPeer.udpClient.getLocalPort())")
            
            let addressList = getIFAddresses()
            for address in addressList {
                print("address: \(address)")
            }
            
            let data = "\(addressList[0]) \(rendezvousKcpPeer.udpClient.getLocalPort()) ios"
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
        print("callback not implemented")
    }
}

func isleep(millisecond:Int) -> Void {
    usleep(useconds_t((millisecond << 10) - (millisecond << 4) - (millisecond << 3)))
}

