//
//  ViewController.swift
//  SwiftSCNet
//
//  Created by dinobei on 05/02/2019.
//  Copyright (c) 2019 dinobei. All rights reserved.
//

import UIKit
import SwiftSCNet
import SwiftProtobuf

class ViewController: UIViewController {
    var client: Client?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let registry = Registry.sharedInstance
        do {
            try registry.registPacket(messageType: DummyPacket1.self) { header, message in
                let packet1 = message as! DummyPacket1
                print("[Packet1 sink callback] title: \(packet1.title), number: \(packet1.number)")
            }
            try registry.registPacket(messageType: DummyPacket2.self) { header, message in
                let packet2 = message as! DummyPacket2
                print("[Packet2 sink callback] strArr: \(packet2.strArr.description)")
            }
            try registry.registPacket(messageType: Ping.self) { header, message in
                print("[Ping sink callback]")
            }
        }
        catch {
            
        }
    }

    @IBAction func onClickConnect(_ sender: Any) {
        if let connected = client?.connected, connected {
            client?.interrupt()
        }
        client = Client(ip: "127.0.0.1", port: 9190, delegate: self)
        let dispatchQueue = DispatchQueue.init(label: "dq")
        dispatchQueue.async {
            self.client?.start(timeout: 3)
        }
    }
    
    @IBAction func onClickDisconnected(_ sender: Any) {
        guard let client = self.client, client.connected else {
            print("not connected")
            return
        }
        self.client?.interrupt()
    }
    
    @IBAction func onClickSendDummyPacket1(_ sender: Any) {
        guard let client = client, client.connected else {
            print("not connected")
            return
        }
        
        var pkt1 = DummyPacket1()
        pkt1.title = "hello world!"
        pkt1.number = 123;
        do {
            let _ = try client.send(message: pkt1, onReceived: { header, message in
                let packet1 = message as! DummyPacket1
                print("[Packet1 dedicated callback] title: \(packet1.title), number: \(packet1.number)")
            }, onTimeout: {print("onTimeout")}, onEnded: {print("onEnded")})
        }
        catch {
            print("catch error")
        }
    }
    
    @IBAction func onClickSendDummyPacket2(_ sender: Any) {
        guard let client = client, client.connected else {
            print("not connected")
            return
        }
        
        var pkt2 = DummyPacket2()
        pkt2.strArr.append("Hello")
        pkt2.strArr.append("World")
        do {
            let _ = try client.send(message: pkt2, onReceived: { header, message in
                let packet2 = message as! DummyPacket2
                print("[Packet1 dedicated callback] strArr: \(packet2.strArr.description)")
            }, onTimeout: {print("onTimeout")}, onEnded: {print("onEnded")})
        }
        catch {
            print("catch error")
        }
    }

}

extension ViewController: ClientDelegate {
    func onAttaching() {
        print("onAttaching")
    }
    
    func onAttached() {
        print("onAttached")
    }
    
    func onTimedOut() {
//        print("onTimedOut")
    }
    
    func onAttachFailed() {
        print("onAttachFailed")
    }
    
    func onDetached() {
        print("onDetached")
    }
}
