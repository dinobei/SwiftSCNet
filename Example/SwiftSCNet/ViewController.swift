//
//  ViewController.swift
//  SwiftSCNet
//
//  Created by dinobei on 05/02/2019.
//  Copyright (c) 2019 dinobei. All rights reserved.
//

import UIKit
import SwiftSCNet

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let server = ServerSession(ip: "127.0.0.1", port: 9190, delegate: self)
        
        let dispatchQueue = DispatchQueue.init(label: "dq")
        dispatchQueue.async {
            server.start(timeout: 1)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension ViewController: ServerSessionDelegate {
    func onAttaching() {
        print("onAttaching")
    }
    
    func onAttached() {
        print("onAttached")
    }
    
    func onAttachFailed() {
        print("onAttachFailed")
    }
    
    func onDetached() {
        print("onDetached")
    }
}
