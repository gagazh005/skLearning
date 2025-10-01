//
//  GameSocketManager.swift
//  snake
//
//  Created by 张欢 on 2025/9/13.
//

import Foundation
import Darwin

protocol GameSocketManagerDelegate: AnyObject {
    func didConnectToServer()
    func didDisconnectFromServer()
    func didReceiveData(_ data: [String: Any])
}

class GameSocketManager {
    weak var delegate: GameSocketManagerDelegate?
    
    // Socket 相关变量
    private var socketFD: Int32 = -1
    private var isConnected = false
    private let receiveQueue = DispatchQueue(label: "com.snake.socket.receive")
    private var isRunning = false
    
    // 非单例 - 可以创建多个实例
    init() {
        // 普通的初始化方法
    }
    
    func connectToServer(host: String, port: Int32) {
        guard !isConnected else {
            print("已经连接到服务器")
            return
        }
        
        // 创建 socket
        socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            print("创建 socket 失败: \(errno)")
            return
        }
        
        // 设置服务器地址
        var serverAddr = sockaddr_in()
        serverAddr.sin_family = sa_family_t(AF_INET)
        serverAddr.sin_port = in_port_t(port).bigEndian
        
        // 解析主机名
        if inet_pton(AF_INET, host, &serverAddr.sin_addr) != 1 {
            // 如果直接 IP 解析失败，尝试通过主机名解析
            guard let hostEntry = gethostbyname(host) else {
                print("解析主机名失败: \(host)")
                close(socketFD)
                return
            }
            serverAddr.sin_addr = hostEntry.pointee.h_addr_list[0]!.withMemoryRebound(to: in_addr.self, capacity: 1) { $0.pointee }
        }
        
        // 连接服务器
        let connectResult = withUnsafePointer(to: &serverAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(socketFD, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard connectResult == 0 else {
            print("连接服务器失败: \(errno) - \(String(cString: strerror(errno)))")
            close(socketFD)
            return
        }
        
        isConnected = true
        isRunning = true
        
        print("连接到服务器成功 [\(host):\(port)]")
        DispatchQueue.main.async {
            self.delegate?.didConnectToServer()
        }
        
        // 开始接收数据
        startReceiving()
    }
    
    func sendData(_ data: [String: Any]) {
        guard isConnected else {
            print("未连接到服务器，无法发送数据")
            return
        }
        
        do {
            // 序列化 JSON 数据
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            let dataLength = Int32(jsonData.count)
            
            // 创建包含长度头的数据包
            var packetData = Data()
            var bigEndianLength = dataLength.bigEndian
            let lengthData = Data(bytes: &bigEndianLength, count: MemoryLayout<Int32>.size)
            packetData.append(lengthData)  // 4 字节长度头
            packetData.append(jsonData)    // JSON 数据
            
            // 发送数据
            let sendResult = packetData.withUnsafeBytes { bufferPointer in
                send(socketFD, bufferPointer.baseAddress, packetData.count, 0)
            }
            
            if sendResult == -1 {
                print("发送数据失败: \(errno) - \(String(cString: strerror(errno)))")
                disconnect()
            } else if sendResult != packetData.count {
                print("发送数据不完整: \(sendResult)/\(packetData.count)")
            }
        } catch {
            print("JSON 序列化失败: \(error)")
        }
    }
    
    private func startReceiving() {
        receiveQueue.async {
            while self.isRunning && self.isConnected {
                // 1. 先接收 4 字节长度头
                guard let headerData = self.receiveExactLength(4) else {
                    print("接收长度头失败，连接可能已断开")
                    break
                }
                
                // 解析长度头
                let dataLength = headerData.withUnsafeBytes { $0.load(as: Int32.self) }.bigEndian
                let expectedLength = Int(dataLength)
                
                // 长度验证
                guard expectedLength > 0 && expectedLength < 10 * 1024 * 1024 else {
                    print("无效的数据长度: \(expectedLength)，断开连接")
                    break
                }
                
                // print("期望接收数据长度: \(expectedLength) bytes")
                
                // 2. 接收完整的数据体
                guard let bodyData = self.receiveExactLength(expectedLength) else {
                    print("接收数据体失败，期望: \(expectedLength)")
                    break
                }
                
                // print("成功接收完整数据包: \(bodyData.count) bytes")
                
                // 3. 处理数据
                self.processCompleteData(bodyData)
            }
            
            // 循环结束，断开连接
            DispatchQueue.main.async {
                self.disconnect()
            }
        }
    }
    
    private func receiveExactLength(_ length: Int) -> Data? {
        var receivedData = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { buffer.deallocate() }
        
        while receivedData.count < length {
            let bytesToRead = min(4096, length - receivedData.count)
            let bytesRead = recv(socketFD, buffer, bytesToRead, 0)
            
            if bytesRead > 0 {
                receivedData.append(buffer, count: bytesRead)
                
                // 只在需要时打印进度（避免日志过多）
                if length > 1000 {
                    let progress = Double(receivedData.count) / Double(length) * 100
                    if receivedData.count % 1000 == 0 { // 每1KB打印一次
                        print("接收进度: \(receivedData.count)/\(length) bytes (\(Int(progress))%)")
                    }
                }
            } else if bytesRead == 0 {
                print("连接被服务器关闭")
                return nil
            } else {
                let errorCode = errno
                if errorCode == EAGAIN || errorCode == EWOULDBLOCK {
                    // 等待数据到达
                    usleep(1000) // 1ms
                    continue
                } else {
                    print("接收数据错误: \(errorCode) - \(String(cString: strerror(errorCode)))")
                    return nil
                }
            }
        }
        
        return receivedData
    }
    
    private func processCompleteData(_ data: Data) {
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                DispatchQueue.main.async {
                    self.delegate?.didReceiveData(jsonObject)
                }
            } else {
                print("❌ 解析的数据不是字典格式")
            }
        } catch {
            print("❌ JSON 解析失败: \(error)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("失败的数据长度: \(data.count)")
                print("数据开头: \(String(dataString.prefix(200)))")
                print("数据结尾: \(String(dataString.suffix(200)))")
            }
        }
    }
    
    func disconnect() {
        guard isConnected else { return }
        
        isRunning = false
        isConnected = false
        
        // 关闭 socket
        if socketFD >= 0 {
            close(socketFD)
            socketFD = -1
        }
        
        print("断开服务器连接")
        DispatchQueue.main.async {
            self.delegate?.didDisconnectFromServer()
        }
    }
    
    deinit {
        print("GameSocketManager 被释放")
        disconnect()
    }
}
