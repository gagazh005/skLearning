//
//  GameSocketManager.swift
//  snake
//
//  Created by 张欢 on 2025/9/13.
//

import Foundation
import Network

protocol GameSocketManagerDelegate: AnyObject {
    func didConnectToServer()
    func didDisconnectFromServer()
    func didReceiveData(_ data: [String: Any])
}

class GameSocketManager {
    weak var delegate: GameSocketManagerDelegate?
    
    private var connection: NWConnection?
    private var host: NWEndpoint.Host?
    private var port: NWEndpoint.Port?
    private var isConnected = false
    
    // 接收状态管理
    private var expectedDataLength: Int = -1
    private var receivedDataBuffer = Data()
    private var isReadingHeader = true
    
    func connectToServer(host: String, port: Int32) {
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: UInt16(port))!
        
        connection = NWConnection(host: self.host!, port: self.port!, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("连接到服务器成功")
                self?.isConnected = true
                self?.delegate?.didConnectToServer()
                self?.receiveData()
                
            case .failed(let error):
                print("连接失败: \(error)")
                self?.isConnected = false
                self?.delegate?.didDisconnectFromServer()
                
            case .cancelled:
                print("连接被取消")
                self?.isConnected = false
                self?.delegate?.didDisconnectFromServer()
                
            default:
                break
            }
        }
        
        connection?.start(queue: .main)
    }
    
    func sendData(_ data: [String: Any]) {
        guard isConnected else {
            print("未连接到服务器，无法发送数据")
            return
        }
        
        do {
            // 序列化JSON数据
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            let dataLength = Int32(jsonData.count)
            
            // 创建包含长度头的数据包
            var packetData = Data()
            let lengthData = withUnsafeBytes(of: dataLength.bigEndian) { Data($0) }
            packetData.append(lengthData)  // 4字节长度头
            packetData.append(jsonData)    // JSON数据
            
            connection?.send(content: packetData, completion: .contentProcessed({ error in
                if let error = error {
                    print("发送数据失败: \(error)")
                }
            }))
        } catch {
            print("JSON序列化失败: \(error)")
        }
    }
    
    private func receiveData() {
        if isReadingHeader {
            // 接收4字节的长度头
            connection?.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, isComplete, error in
                self?.handleHeaderData(data, isComplete: isComplete, error: error)
            }
        } else {
            // 接收JSON数据体
            let bytesToRead = expectedDataLength - receivedDataBuffer.count
            connection?.receive(minimumIncompleteLength: bytesToRead, maximumLength: bytesToRead) { [weak self] data, _, isComplete, error in
                self?.handleBodyData(data, isComplete: isComplete, error: error)
            }
        }
    }
    
    private func handleHeaderData(_ data: Data?, isComplete: Bool, error: Error?) {
        if let error = error {
            print("接收长度头错误: \(error)")
            disconnect()
            return
        }
        
        if isComplete {
            print("连接关闭")
            disconnect()
            return
        }
        
        guard let data = data, data.count == 4 else {
            print("无效的长度头数据")
            disconnect()
            return
        }
        
        // 解析长度头
        expectedDataLength = Int(data.withUnsafeBytes { $0.load(as: Int32.self) }.bigEndian)
        
        if expectedDataLength > 0 {
            isReadingHeader = false
            receivedDataBuffer = Data()
        } else {
            print("无效的数据长度: \(expectedDataLength)")
            resetReceiveState()
        }
        receiveData() 
    }
    
    private func handleBodyData(_ data: Data?, isComplete: Bool, error: Error?) {
        if let error = error {
            print("接收数据体错误: \(error)")
            disconnect()
            return
        }
        
        if isComplete {
            print("连接关闭")
            disconnect()
            return
        }
        
        guard let data = data else {
            print("收到空数据")
            resetReceiveState()
            receiveData()
            return
        }
        
        // 累积接收到的数据
        receivedDataBuffer.append(data)
        
        if receivedDataBuffer.count >= expectedDataLength {
            // 收到完整的数据包
            let completeData = receivedDataBuffer.prefix(expectedDataLength)
            processCompleteData(Data(completeData))
            // 处理可能的多余数据（粘包情况）
            if receivedDataBuffer.count > expectedDataLength {
                let remainingData = receivedDataBuffer.suffix(from: expectedDataLength)
                print("警告：收到多余数据，可能粘包，长度: \(remainingData.count)")
            }
            resetReceiveState()
        }
        receiveData()
    }
    
    private func processCompleteData(_ data: Data) {
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                self.delegate?.didReceiveData(jsonObject)
            } else {
                print("解析的数据不是字典格式")
            }
        } catch {
            print("JSON解析失败: \(error)")
            if let dataString = String(data: data, encoding: .utf8) {
                print("失败的数据: \(dataString)")
            }
        }
    }
    
    private func resetReceiveState() {
        expectedDataLength = -1
        receivedDataBuffer = Data()
        isReadingHeader = true
    }
    
    func disconnect() {
        isConnected = false
        resetReceiveState()
        connection?.cancel()
        delegate?.didDisconnectFromServer()
    }
    
    deinit {
        disconnect()
    }
}
