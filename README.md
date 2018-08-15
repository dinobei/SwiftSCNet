# SCNet-Swift
iOS, macOS용 네트워크 송수신 프레임워크 라이브러리

## 개요
C++, Swift, Java(Android), C# 에서 공용 헤더 사용으로 네트워크 송수신 과정 통합

## 기능
- MSB Varint32 Encoding된 헤더 사용
	- 암호화 기능
	- 패킷 타입 지정 가능 (`protobuf`, flatBuffer, native byte array, utf8 string, ...)
- 네트워크 연결상태에 따른 콜백 함수 구현

## 사용방법
SCNet-Swift 프로젝트 빌드 후, `SwiftProtobuf.framework`, `SwiftSocket.framework`, `SCNet-Swift.framework`를 iOS 프로젝트 설정에 **Embedded Binary**에 드래그앤드랍하여 사용 (링크(X), 프로젝트 내 복사(O) )

```swift
class ViewController {
    var client: ClientManager?
    override func viewDidLoad() {
        super.viewDidLoad()
        client = ClientManager(ip: "127.0.0.1", port: 9190, delegate: self)

        // Register messages
        let reg = Registry.sharedInstance
        
        do {
            try reg.regist(key: Simple_packet_1.protoMessageName, typeInt: 0)
            try reg.regist(key: Simple_packet_2.protoMessageName, typeInt: 1)
            try reg.regist(key: Simple_packet_3.protoMessageName, typeInt: 2)
            try reg.regist(key: Simple_packet_4.protoMessageName, typeInt: 3)
        }
        catch(let err) {
            print("err: \(err)")
        }

        client?.attach()

        ...
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        client?.detach()
    }
}

extension ViewController: ClientManagerDelegate {
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
    
    func onCallback(messageHeader: MessageHeader, data: [UInt8]) {
        ...
    }
}
```

## 라이브러리 종속성
- CocoaPod
	- SwiftProtobuf
	- SwiftSocket (https://github.com/dinobei/SwiftProtobuf)


