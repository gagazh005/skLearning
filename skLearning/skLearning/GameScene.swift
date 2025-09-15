import SpriteKit

class GameScene: SKScene {
    var currentLine: SKShapeNode?  // 当前绘制的直线
    var currentCircle: SKShapeNode?  // 当前绘制的圆圈
    private let snakeHeadNode = SKSpriteNode(imageNamed: "snakeHead")
    private var joyStick: JoyStick!
    var startPoint: CGPoint?      // 起点位置
    
    // MARK: - 网络管理
    var socketManager: GameSocketManager!
    let serverHost = "192.168.1.17"
    let serverPort: Int32 = 5555
    
    // 服务器定义的边界（根据你的Python服务器代码）
    let serverBounds = CGRect(x: 0, y: 0, width: 800, height: 600) // 根据你的服务器调整
        
    // 客户端显示边界（会根据设备自动计算）
    var displayBounds: CGRect = .zero
    
    // 缩放比例
    var scaleFactor: CGFloat = 1.0
    
    // MARK: - 游戏属性
    var players: [String: PlayerNode] = [:]
    var myPlayerId: String?
    var lastMovementTime: TimeInterval = 0
    let movementInterval: TimeInterval = 0.1
    var currentMovement = CGVector(dx: 0,dy: 0)
    
    // MARK: - UI元素
    var statusLabel: SKLabelNode!
    var connectButton: SKSpriteNode!
    var playerIdLabel: SKLabelNode!
    var playersCountLabel: SKLabelNode!
    
    override func didMove(to view: SKView) {
        setupBackground()
        // 计算并绘制边界
        calculateDisplayBounds()
        setupGameBorder()
        setupUI()
        setupNetwork()
        // 调整UI位置，避免被边界遮挡
        adjustUIPosition()
        
        // backgroundColor = .black
        setupJoyStick()
        snakeHeadNode.scale(to: CGSize(width: 50, height: 50))
        snakeHeadNode.position = CGPoint(x: frame.midX, y: frame.midY)
        snakeHeadNode.name = "蛇头"
        startPoint = snakeHeadNode.position
        addChild(snakeHeadNode)
        
    }
    
    func serverToScreenPosition(_ serverPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: displayBounds.minX + serverPoint.x * scaleFactor,
            y: displayBounds.minY + serverPoint.y * scaleFactor
        )
    }

    // 屏幕坐标 → 服务器坐标
    func screenToServerPosition(_ screenPoint: CGPoint) -> CGPoint {
        return CGPoint(
            x: (screenPoint.x - displayBounds.minX) / scaleFactor,
            y: (screenPoint.y - displayBounds.minY) / scaleFactor
        )
    }

    // 服务器距离 → 屏幕距离
    func serverToScreenDistance(_ distance: CGFloat) -> CGFloat {
        return distance * scaleFactor
    }
    
    func calculateDisplayBounds() {
        // 获取屏幕可用空间（考虑安全区域）
        let safeAreaInsets = view?.safeAreaInsets ?? UIEdgeInsets.zero
        let availableWidth = size.width - safeAreaInsets.left - safeAreaInsets.right
        let availableHeight = size.height - safeAreaInsets.top - safeAreaInsets.bottom
        
        // 计算保持纵横比的缩放因子
        let widthScale = availableWidth / serverBounds.width
        let heightScale = availableHeight / serverBounds.height
        scaleFactor = min(widthScale, heightScale)
        
        // 计算实际显示尺寸
        let displayWidth = serverBounds.width * scaleFactor
        let displayHeight = serverBounds.height * scaleFactor
        
        // 计算居中位置
        let xOffset = (size.width - displayWidth) / 2 + safeAreaInsets.left
        let yOffset = (size.height - displayHeight) / 2 + safeAreaInsets.top
        
        displayBounds = CGRect(x: xOffset, y: yOffset, width: displayWidth, height: displayHeight)
        
        print("服务器边界: \(serverBounds)")
        print("显示边界: \(displayBounds)")
        print("缩放因子: \(scaleFactor)")
    }
    
    func setupGameBorder() {
        // 创建边界框
        let border = SKShapeNode(rect: displayBounds)
        border.name = "gameBorder"
        border.strokeColor = SKColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
        border.lineWidth = 2
        border.fillColor = .clear
        border.zPosition = -1 // 在背景层
        
        addChild(border)
    }
    
    func setupBackground() {
        backgroundColor = SKColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
    }
    
    func setupUI() {
        // 状态标签
        statusLabel = SKLabelNode(text: "未连接")
        statusLabel.position = CGPoint(x: frame.midX, y: frame.height - 40)
        statusLabel.fontColor = .red
        statusLabel.fontSize = 16
        addChild(statusLabel)
        
        // 玩家ID标签 - 添加在左上角
        playerIdLabel = SKLabelNode(text: "|ID: 未连接")
        playerIdLabel.position = CGPoint(x: 100, y: frame.height - 40) // 左上角位置
        playerIdLabel.fontColor = .blue
        playerIdLabel.fontSize = 14
        playerIdLabel.horizontalAlignmentMode = .left // 左对齐
        playerIdLabel.zPosition = 100 // 确保在最上层
        playerIdLabel.name = "playerIdLabel"
        addChild(playerIdLabel)

        // 玩家数量标签
        playersCountLabel = SKLabelNode(text: "玩家: 0")
        playersCountLabel.position = CGPoint(x: 30, y: frame.height - 40)
        playersCountLabel.fontColor = .darkGray
        playersCountLabel.fontSize = 14
        addChild(playersCountLabel)
        
        // 连接按钮
        connectButton = SKSpriteNode(color: .purple, size: CGSize(width: 100, height: 30))
        connectButton.position = CGPoint(x: frame.width - 60, y: frame.height - 40)
        connectButton.name = "connectButton"
        
        let buttonLabel = SKLabelNode(text: "连接")
        buttonLabel.fontColor = .white
        buttonLabel.fontSize = 12
        buttonLabel.verticalAlignmentMode = .center
        connectButton.addChild(buttonLabel)
        
        addChild(connectButton)
    }
    
    private func setupJoyStick() {
        joyStick = JoyStick()
        joyStick.positionInLowerLeftCorner(of: self)
        addChild(joyStick)
        
        // 设置方向变化回调
        joyStick.onDirectionChanged = { [weak self] angle, intensity in
            self?.handleDirectionChange(angle: angle, intensity: intensity)
        }
    }
    
    private func handleDirectionChange(angle: CGFloat, intensity: CGFloat) {
        // 根据方向盘输入调转蛇头
        currentMovement = joyStick.getDirectionVector()
        if intensity > 0.5 {
            snakeHeadNode.zRotation = angle
        }
    }
    
    // MARK: - 游戏循环
    override func update(_ currentTime: TimeInterval) {
        playersCountLabel.text = "玩家: \(players.count)"
        
        // 处理连续移动
        if currentMovement != CGVector(dx: 0, dy: 0) {
            if currentTime - lastMovementTime >= movementInterval {
                sendMovementToServer()
                lastMovementTime = currentTime
            }
        }
    }
    
    func sendMovementToServer() {
        guard let _ = myPlayerId, currentMovement != CGVector(dx: 0, dy: 0) else {
            return
        }
        
        let movementData: [String: Any] = [
            "type": "movement",
            "movement": [currentMovement.dx, currentMovement.dy]
        ]
        socketManager.sendData(movementData)
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        
        // 屏幕尺寸变化时重新计算边界
        calculateDisplayBounds()
        setupGameBorder()
        adjustUIPosition()
    }
    
    func adjustUIPosition() {
        guard let _ = statusLabel else {
            print("还没有初始化UI元素，就开始调整位置！")
            return
        }
        // 将UI元素移到边界外
        statusLabel.position = CGPoint(x: size.width / 2, y: displayBounds.maxY - 40)
        playersCountLabel.position = CGPoint(x: 30, y: displayBounds.maxY - 40)
        playerIdLabel.position = CGPoint(x: 100, y: displayBounds.maxY - 40)
        connectButton.position = CGPoint(x: size.width - 60, y: displayBounds.maxY - 20)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let startPoint = startPoint else { return }
        if let _ = currentCircle, let _ = currentLine { return }
        let location = touch.location(in: self)
        let nodes = self.nodes(at: location)
        
        //print("触摸位置: \(location)")
        //print("触摸到的节点: \(nodes.map { $0.name ?? "无名节点" })")
        
        for node in nodes {
            if node.name == "connectButton" || node.parent?.name == "connectButton" {
                connectToServer()
                return
            }
        }
        
        // 创建新的圆圈
        currentCircle = createCircle(at: location)
        currentCircle.map { addChild($0) }
        
        // 创建新的直线
        currentLine = createLine(from: startPoint, to: location)
        currentLine.map { addChild($0) }
        
        // 蛇头朝向触摸点
        towards(to: location)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 更新直线和圆圈到当前手指位置
        updateLine(to: location)
        updateCircle(to: location)
        // 蛇头朝向触摸点
        towards(to: location)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 触摸结束时移除直线和圆圈
        removeLine()
        removeCircle()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 触摸取消时移除直线和圆圈
        removeLine()
        removeCircle()
    }
    
    // 创建圆圈
    func createCircle(at center: CGPoint) -> SKShapeNode {
        let circle = SKShapeNode(circleOfRadius: 25) // 半径25
        circle.name = "圆圈"
        circle.position = center
        circle.strokeColor = .white // 边框颜色
        circle.lineWidth = 2        // 边框粗细
        return circle
    }
    
    // 更新圆圈
    func updateCircle(to position: CGPoint) {
        currentCircle?.position = position
    }
    
    func removeCircle() {
        // 消失动画（0.5秒后）
        let fadeOut = SKAction.fadeOut(withDuration: 0.5)
        let remove = SKAction.removeFromParent()
        let sequence = SKAction.sequence([fadeOut, remove])
        currentCircle?.run(sequence)
        currentCircle?.removeFromParent()
        currentCircle = nil
    }
    
    // 创建直线
    func createLine(from start: CGPoint, to end: CGPoint) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        
        let line = SKShapeNode(path: path)
        line.name = "直线"
        line.strokeColor = .red
        line.lineWidth = 3
        line.glowWidth = 1
        return line
    }
    
    // 更新直线终点
    func updateLine(to endPoint: CGPoint) {
        guard let startPoint = startPoint else { return }
        
        let path = CGMutablePath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        
        currentLine?.path = path
    }
    
    func removeLine() {
        currentLine?.removeFromParent()
        currentLine = nil
    }
    
    func towards(to point: CGPoint) {
        guard let startPoint = startPoint else { return }
        let theta = atan2(point.y - startPoint.y, point.x - startPoint.x)
        snakeHeadNode.zRotation = theta
    }
    
    func setupNetwork() {
        socketManager = GameSocketManager()
        socketManager.delegate = self
    }
    
    func connectToServer() {
        statusLabel.text = "连接中..."
        statusLabel.fontColor = .yellow
        socketManager.connectToServer(host: serverHost, port: serverPort)
    }
    
    // MARK: - 玩家管理
    func createPlayerNode(id: String, x: CGFloat, y: CGFloat, color: SKColor) -> PlayerNode {
        let player = PlayerNode(id: id)
            let screenPosition = serverToScreenPosition(CGPoint(x: x, y: y))
            player.position = screenPosition
            player.fillColor = color
            
            // 根据缩放调整玩家大小
            let playerSize = serverToScreenDistance(20) // 假设服务器端玩家大小为20
            player.path = CGPath(roundedRect: CGRect(x: -playerSize/2, y: -playerSize/2,
                                                   width: playerSize, height: playerSize),
                                cornerWidth: playerSize/4, cornerHeight: playerSize/4,
                                transform: nil)
        
        // 添加玩家ID标签
        let idLabel = SKLabelNode(text: id)
        idLabel.fontSize = 8
        idLabel.fontColor = .black
        idLabel.position = CGPoint(x: 0, y: -25)
        idLabel.zPosition = 11
        player.addChild(idLabel)
        
        return player
    }
    
    func updatePlayerPosition(id: String, x: CGFloat, y: CGFloat) {
        if let player = players[id] {
            let screenPosition = serverToScreenPosition(CGPoint(x: x, y: y))
            let moveAction = SKAction.move(to: screenPosition, duration: 0.1)
            player.run(moveAction)
        }
    }
    
    func removePlayer(id: String) {
        players[id]?.removeFromParent()
        players.removeValue(forKey: id)
    }
    
}

// MARK: - 玩家节点类
class PlayerNode: SKShapeNode {
    let playerId: String
    
    init(id: String) {
        self.playerId = id
        super.init()
        self.name = "player_\(id)"
        self.path = CGPath(roundedRect: CGRect(x: -10, y: -10, width: 20, height: 20),
                          cornerWidth: 5, cornerHeight: 5, transform: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - 网络管理器代理
extension GameScene: GameSocketManagerDelegate {
    func didConnectToServer() {
        statusLabel.text = "已连接"
        statusLabel.fontColor = .green
    }
    
    func didDisconnectFromServer() {
        statusLabel.text = "连接断开"
        statusLabel.fontColor = .red
        
        // 清理所有玩家
        for (id, _) in players {
            removePlayer(id: id)
        }
        myPlayerId = nil
        
        print("与服务器断开连接")
    }
    
    func didReceiveData(_ data: [String: Any]) {
        guard let type = data["type"] as? String else { return }
        
        switch type {
        case "add_player":
            handleAddPlayer(data)
        case "game_state":
            handleGameState(data)
        default:
            print("未知消息类型: \(type)")
        }
    }
    
    private func handleAddPlayer(_ data: [String: Any]) {
        guard let playerId = data["id"] as? String,
              let playersData = data["players"] as? [String: [String: Any]] else {
            print("无效的add_player数据")
            return
        }
        
        myPlayerId = playerId
        print("我的玩家ID: \(playerId)")
        playerIdLabel.text = "ID: \(playerId)"
        
        // 初始化所有玩家
        for (id, playerData) in playersData {
            if let x = playerData["x"] as? CGFloat,
               let y = playerData["y"] as? CGFloat,
               let colorArray = playerData["color"] as? [Int],
               colorArray.count == 3 {
                
                let color = SKColor(red: CGFloat(colorArray[0])/255.0,
                                  green: CGFloat(colorArray[1])/255.0,
                                  blue: CGFloat(colorArray[2])/255.0,
                                  alpha: 1.0)
                
                let playerNode = createPlayerNode(id: id, x: x, y: y, color: color)
                players[id] = playerNode
                addChild(playerNode)
            }
        }
    }
    
    private func handleGameState(_ data: [String: Any]) {
        guard let playersData = data["players"] as? [String: [String: Any]] else {
            print("无效的game_state数据")
            return
        }
        
        // 更新现有玩家位置
        for (id, playerData) in playersData {
            if let x = playerData["x"] as? CGFloat,
               let y = playerData["y"] as? CGFloat {
                
                if players[id] != nil {
                    updatePlayerPosition(id: id, x: x, y: y)
                } else if let colorArray = playerData["color"] as? [Int],
                          colorArray.count == 3 {
                    
                    let color = SKColor(red: CGFloat(colorArray[0])/255.0,
                                      green: CGFloat(colorArray[1])/255.0,
                                      blue: CGFloat(colorArray[2])/255.0,
                                      alpha: 1.0)
                    
                    let playerNode = createPlayerNode(id: id, x: x, y: y, color: color)
                    players[id] = playerNode
                    addChild(playerNode)
                }
            }
        }
        
        // 移除已断开连接的玩家
        let currentPlayerIds = Set(playersData.keys)
        let existingPlayerIds = Set(players.keys)
        let disconnectedPlayers = existingPlayerIds.subtracting(currentPlayerIds)
        
        for id in disconnectedPlayers {
            removePlayer(id: id)
        }
    }
}
