# SCNet-Swift

[![CI Status](https://img.shields.io/travis/dinobei/SwiftSCNet.svg?style=flat)](https://travis-ci.org/dinobei/SwiftSCNet)
[![Version](https://img.shields.io/cocoapods/v/SwiftSCNet.svg?style=flat)](https://cocoapods.org/pods/SwiftSCNet)
[![License](https://img.shields.io/cocoapods/l/SwiftSCNet.svg?style=flat)](https://cocoapods.org/pods/SwiftSCNet)
[![Platform](https://img.shields.io/cocoapods/p/SwiftSCNet.svg?style=flat)](https://cocoapods.org/pods/SwiftSCNet)

- iOS, macOS용 네트워크 송수신 프레임워크 라이브러리
- Swift 4.2 지원

## 개요
- SCNet?
- 다양한 플랫폼(C++, Android(Java), iOS(Swift), Windows(C#), Nodejs(Javascript))을 지원하는 크로스플랫폼 네트워크 프레임워크

## 기능
- 고정 사이즈 헤더 기반 패킷 송수신
    - MSB Varint32 Encoding된 헤더 컴포넌트 사용
    - 패킷 암호화 기능 (준비중)
    - 송수신 패킷 타입 지정 (`protobuf`, flatBuffer, native byte array, ...)
- ServerSession
    - TCP 기반 서버와 통신하기 위한 기능 제공
    - 네트워크 연결상태에 따른 콜백 함수 구현
- RendezvousClient
    - Reliable-UDP 기반 피어(서버 or 클라이언트)와 통신
    - 네트워크 상태에 따라 Relay, Hole-Punching, Direct connection, Reverse connection 자동 연결

## 설치

```ruby
pod 'SwiftSCNet', '~>0.1.0'
```

## 사용방법
- Xcode 프로젝트에 프레임워크 추가
    - SCNet-Swift 프로젝트 빌드하여 `SCNet-Swift.framework`, `SwiftProtobuf.framework`, `SwiftSocket.framework`를 생성
    - 개발할 iOS/macOS Xcode 프로젝트 설정페이지에서 **Target**-**General** **Embedded Binary**에 framework를 추가 (**링크(O)**, 프로젝트내 복사(X))

- 패킷 송수신을 위한 메시지 등록

```swift
let reg = Registry.sharedInstance

do {
    try registry.registRawBytePacket(packetType: 0) { (packetType, data)->Void in
        print("rawbyte, packetType: \(packetType), data: \(String(bytes: data, encoding: .utf8) ?? "nil")")
    }
    try registry.registRawBytePacket(packetType: 0) { (packetType, data)->Void in
        print("rawbyte, packetType: \(packetType), data: \(String(bytes: data, encoding: .utf8) ?? "nil")")
    }
    try registry.registProtobufPacket(messageType: Simple_packet_1.self, packetType: 0, callback: nil)
    try registry.registProtobufPacket(messageType: Simple_packet_2.self, packetType: 1) { message in
        let response = message as! Simple_packet_2
        ...
    }
}
catch(let err) {
    print("err: \(err)")
}
```

- ServerSession 사용방법

```swift
...
import SCNetSwift
...

class ViewController {
    var server: ServerManager?
    override func viewDidLoad() {
        super.viewDidLoad()
        server = ServerSession(ip: "1.1.1.1", port: 11111, delegate: self)

        let dispatchQueue = DispatchQueue.init(label: "dq")
        dispatchQueue.async {
            self.server.start(timeout: 1)
        }

        ...
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        server?.interrupt()
    }


}

extension ViewController: ServerSessionDelegate {
    func onAttaching() {
        ...
    }
    
    func onAttached() {
        ...
    }
    
    func onAttachFailed() {
        ...
    }
    
    func onDetached() {
        ...
    }
}
```

- RendezvousClient 사용방법

```swift
// 1. RendezvousClientDelegate 프로토콜 구현. 다른 Peer와 연결시도시 연결상태를 알기 위해 필요함
func onConnectedToRendezvousServer(_ myPublicIP: String, _ myPublicPort: String) {
}
func onTargetInvalid(_ targetIP: String, _ targetPort: Int) {
}
func onConnectionIDCreated(_ rendezvousSession: RendezvousSession, _ targetIP: String, _ targetPort: Int) {
}
func onConnecting(_ connectionID: Int) {
}
func onConnected(_ rendezvousSession: RendezvousSession, _ connection: Connection) {
}
func onConnectionUpdate(_ rendezvousSession: RendezvousSession, _ connection: Connection) {
}

// 2. RendezvousClient 생성
var rendezvousClient = RendezvousClient.init(rendezvousServerIP: "1.1.1.1", port: 11111, delegate: self)

// 3. RendezvousClient 시작
let dispatchQueue = DispatchQueue.init(label: "dq")
dispatchQueue.async {
    self.server.start(timeout: 1)
}

// 4. RendezvousCient 종료
rendezvousClient.stop()

// 5. Peer에 연결
rendezvousClient.connect(ip: "1.1.1.1", port: "11111")

// 6. RendezvousServer에 메시지 전송
let request = Simple_packet_1()
rendezvousClient.send(message: request)

// 7. 다른 RendezvousClient에 메시지 전송
let request = Simple_packet_1()
rendezvousSession.send(request: request) // rendezvousSession은 5번 과정을 통해 onConnected() 콜백의 파라미터로 얻을 수 있음
```

## 라이브러리 종속성
- CocoaPod
    - SwiftProtobuf
    - SwiftSocket (https://github.com/dinobei/SwiftProtobuf)

## License

SwiftSCNet is available under the MIT license. See the LICENSE file for more info.
