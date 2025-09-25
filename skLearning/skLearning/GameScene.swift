import SpriteKit
import Foundation
import AVFoundation

class GameScene: SKScene {
    private var currentLine: SKShapeNode?  // 当前绘制的直线
    private var currentCircle: SKShapeNode?  // 当前绘制的圆圈
    private var joyStick: JoyStick!
    private var startPoint: CGPoint? = CGPoint(x: 0,y: 0)      // 起点位置
    
    // MARK: - 网络管理
    private var socketManager: GameSocketManager!
    private let serverHost = "192.168.1.17"
    private let serverPort: Int32 = 5555
    private var connected = false
    
    // 服务器定义的边界（根据Python服务器数据调整）
    var serverBounds = CGRect(x: 0, y: 0, width: 40, height: 30) 
        
    // 客户端显示边界（会根据设备自动计算）
    var displayBounds: CGRect = .zero
    
    // 缩放比例
    var scaleFactor: CGFloat = 1.0
    
    // MARK: - 游戏属性
    var gamePaused: Bool = false {
        didSet {
            if gamePaused {
                backgroundMusic?.pause()
            } else {
                backgroundMusic?.play()
            }
        }
    }
    var gameState: [String : Any] = [:]
    let allFood = SKNode()
    let ranking = SKNode()
    var players: [String: SKNode] = [:]
    var myPlayerId: String?
    var lastMovementTime: TimeInterval = 0
    var lastUpdateTime: TimeInterval = 0
    let movementInterval: TimeInterval = 0.1
    let updateInterval: TimeInterval = 0.1
    var currentMovement = CGVector(dx: 0,dy: 0)
    var foodTypes: [String: [String: Any]]?
    var effectTimesDict: [String: CGFloat] = [ : ]
    var invisibleFactor: CGFloat?
    
    // MARK: - 设定背景和UI元素
    var statusLabel: SKLabelNode!
    var connectButton: SKSpriteNode!
    var playerIdLabel: SKLabelNode!
    var playersCountLabel: SKLabelNode!
    var effectCooldownTimersDict: [String: CooldownTimerNode] = [:]

    // MARK： - 游戏多媒体
    var foodTextures: [SKTexture] = []
    var snakeHeadTexture: SKTexture = SKTexture(imageNamed: "snakeHead")
    var snakeBodyTexture: SKTexture = SKTexture(imageNamed: "snakeBody")
    var backgroundMusic: AVAudioPlayer?
    var eatSound: AVAudioPlayer?
    var deathSound: AVAudioPlayer?
    
    override func didMove(to view: SKView) {
        setupBackground()
        // 计算并绘制边界
        calculateDisplayBounds()
        setupGameBorder()
        setupUI()
        setupNetwork()
        // 调整UI位置，避免被边界遮挡
        adjustUIPosition()
        setupJoyStick()
        for index in 0...66 {
            let texture = SKTexture(imageNamed: "food_\(index)")
            foodTextures.append(texture)
        }
        setupAudio()
    }

    func setupAudio() {
        // 预加载音效
        if let musicURL = Bundle.main.url(forResource: "background", withExtension: "ogg"),
           let eatURL = Bundle.main.url(forResource: "eat_sound", withExtension: "mp3"),
           let deathURL = Bundle.main.url(forResource: "death_sound", withExtension: "mp3") {
            do {
                backgroundMusic = try AVAudioPlayer(contentsOf: musicURL)
                backgroundMusic?.numberOfLoops = -1 // 无限循环
                backgroundMusic?.volume = 0.5 // 音量 50%
                backgroundMusic?.prepareToPlay()
                eatSound = try AVAudioPlayer(contentsOf: eatURL)
                eatSound?.prepareToPlay() 
                deathSound = try AVAudioPlayer(contentsOf: eatURL)
                deathSound?.prepareToPlay()
            } catch {
                print("无法加载音效")
            }
        }
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
    }
    
    func setupGameBorder() {
        
        // 如果已经有边界框就重用它，否则创建边界框
        if let border = childNode(withName: "gameBorder") as? SKShapeNode {
            border.path = UIBezierPath(rect: displayBounds).cgPath
        } else {
            let border = SKShapeNode(rect: displayBounds)
            border.name = "gameBorder"
            border.strokeColor = SKColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
            border.lineWidth = 2
            border.fillColor = .clear
            border.zPosition = -1 // 在背景层
            addChild(border)
        }
    }
    
    func setupBackground() {
        backgroundColor = SKColor(red: 0, green: 0, blue: 0, alpha: 1.0)
    }
    
    func setupUI() {
        // 状态标签
        statusLabel = SKLabelNode(text: "未连接")
        statusLabel.position = CGPoint(x: frame.midX, y: frame.height - 40)
        statusLabel.fontColor = .red
        statusLabel.fontName = "PingFangSC-Semibold"
        statusLabel.fontSize = 16
        addChild(statusLabel)
        
        // 玩家ID标签 - 添加在左上角
        playerIdLabel = SKLabelNode(text: "|ID: 未连接")
        playerIdLabel.position = CGPoint(x: 100, y: frame.height - 40) // 左上角位置
        playerIdLabel.fontColor = .white
        playerIdLabel.fontName = "PingFangSC-Semibold"
        playerIdLabel.fontSize = 15
        playerIdLabel.horizontalAlignmentMode = .left // 左对齐
        playerIdLabel.zPosition = 100 // 确保在最上层
        playerIdLabel.name = "playerIdLabel"
        addChild(playerIdLabel)

        // 玩家数量标签
        playersCountLabel = SKLabelNode(text: "玩家: 0")
        playersCountLabel.position = CGPoint(x: 30, y: frame.height - 40)
        playersCountLabel.fontColor = .white
        playersCountLabel.fontName = "PingFangSC-Semibold"
        playersCountLabel.fontSize = 15
        addChild(playersCountLabel)
        
        // 连接按钮
        connectButton = SKSpriteNode(color: .purple, size: CGSize(width: 100, height: 30))
        connectButton.position = CGPoint(x: frame.width - 60, y: frame.height - 40)
        connectButton.name = "connectButton"
        
        let buttonLabel = SKLabelNode(text: "连接")
        buttonLabel.name = "connectButtonLabel"
        buttonLabel.fontColor = .white
        buttonLabel.fontSize = 12
        buttonLabel.verticalAlignmentMode = .center
        connectButton.addChild(buttonLabel)
        
        addChild(connectButton)
    }
    
    // MARK: - 捕捉摇杆和触屏输入信号
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let startPoint = startPoint else { return }
        if let _ = currentCircle, let _ = currentLine { return }
        let location = touch.location(in: self)
        let nodes = self.nodes(at: location)
        
        // print("触摸位置: \(location)")
        // print("触摸到的节点: \(nodes.map { $0.name ?? "无名节点" })")
        
        for node in nodes {
            if node.name == "connectButton" || node.parent?.name == "connectButton" {
                if !connected {
                    connectToServer()
                    sendUsernameToServer()
                    guard let LabelNode = connectButton.childNode(withName: "connectButtonLabel") as? SKLabelNode else { return }
                    LabelNode.text = "断开连接"
                } else {
                    sendQuitGameToServer()
                    didDisconnectFromServer()
                    guard let LabelNode = connectButton.childNode(withName: "connectButtonLabel") as? SKLabelNode else { return }
                    LabelNode.text = "连接"
                }
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
        if intensity > 0.5 {
            // 根据方向盘输入调转蛇头
            currentMovement = joyStick.getDirectionVector()
        }
    }
    
    // MARK: - 游戏循环
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        // 处理连续移动
        if currentMovement != CGVector(dx: 0, dy: 0) {
            if currentTime - lastMovementTime >= movementInterval {
                sendMovementToServer()
                lastMovementTime = currentTime
            }
        }
        // 处理游戏状态更新
        if currentTime - lastUpdateTime >= updateInterval {
            handleGameState(gameState)
            lastUpdateTime = currentTime
        }
    }
    
    // MARK: - 收发、处理游戏数据
    private func handleGameEvent(_ data: [String: Any]) {
        guard let gameEvent = data["game_event"] as? String, let content = data["content"] else { return }
        var message = ""
        switch gameEvent {
        case "join_game":
            guard let content = content as? [String: Any] else { return }
            if let gameConfig = content["game_config"] as? [String : Any] {
                loadConfig(gameConfig)
                guard let playerId = content["player_id"] as? Int else { return }
                myPlayerId = String(playerId)
                playerIdLabel.text = "ID: \(playerId)"
                addChild(ranking)
                message = "加入服务器端成功"
                gamePaused = data["game_paused"] as? Bool ?? false
                if gamePaused {
                    message = "游戏暂停中"
                }
            }
        case "game_over":
            message = "游戏结束！"
        case "quit_game":
            message = "退出游戏"
            backgroundMusic?.stop()
        case "reborn":
            message = "重生成功"
            backgroundMusic?.play()
        case "pause_game":
            guard let (gamePaused, playerId, name, pauseCount) = content as? (Bool, String, String, Int) else { return }
            self.gamePaused = gamePaused
            if gamePaused {
                message = "玩家\(playerId):\(name)暂停游戏,还剩\(pauseCount)次"
            } else {
                message = "玩家\(player_id):\(name)恢复游戏"
            }
        case "eating_food":
            eatSound?.play()
            guard let foodName = content as? String else { return }
            guard let foodDetail = foodTypes?[foodName] as? [String: Any] else { return }
            guard let effect = foodDetail["effect"] as? String, let points = foodDetail["points"] as? Int else { return }
            message = "吃了\(foodName),\(effect),加\(points)分"
            guard let cooldownTimer = effectCooldownTimersDict[effect], let effect_time = foodDetail["effect_time"] as? Double else { return }
            cooldownTimer.duration = effect_time
            cooldownTimer.startCooldown()
            cooldownTimer.isHidden = false
        case "crash":
            backgroundMusic?.pause()
            deathSound?.play()
            message = "撞毁"
        default:
            message = "游戏事件类型错误!"
        }
        statusLabel.text = message
        statusLabel.fontColor = .white
    }
    
    private func loadConfig(_ gameConfig: [String: Any]) {
        // self.s_version = game_config["s_version"]
        guard let grid = gameConfig["grid"] as? [Int] else { return }
        let width = grid[0]
        let height = grid[1]
        serverBounds = CGRect(x: 0, y: 0, width: width, height: height)
        calculateDisplayBounds()
        setupGameBorder()
        adjustUIPosition()
        
        invisibleFactor = gameConfig["invisible_factor"] as? CGFloat
        foodTypes = gameConfig["food_types"] as? [String: [String: Any]]
        guard let effectNamesArray = foodTypes?.compactMap({ $1.keys.contains("effect_time") ? $1["effect"] : nil }) as? [String] else { return }
        guard let effectTimesArray = foodTypes?.compactMap({ $1.keys.contains("effect_time") ? $1["effect_time"] : nil }) as? [CGFloat] else { return }
        effectTimesDict = Dictionary(uniqueKeysWithValues: zip(effectNamesArray, effectTimesArray))
        effectCooldownTimersDict = createCooldownTimers(nameArray: effectNamesArray)
    }

    private func createCooldownTimers(nameArray: [String]) -> [String: CooldownTimerNode] {
        // 创建冷却计时器组
        let cooldownTimers = Dictionary(uniqueKeysWithValues: nameArray.indices.map {
            let cooldownTimer = CooldownTimerNode()
            cooldownTimer.isHidden = true
            let xPos = size.width - 10 - cooldownTimer.radius - (10 + 2 * cooldownTimer.radius) * CGFloat($0)
            let yPos = 10 + cooldownTimer.radius
            cooldownTimer.position = CGPoint(x: xPos, y: yPos)
            let effectName = nameArray[$0]
            cooldownTimer.nameLabel.text = String(effectName.prefix(1))
            addChild(cooldownTimer)
            return (nameArray[$0], cooldownTimer)
        })
        return cooldownTimers
    }


    private func handleGameState(_ data: [String : Any]) {
        guard let playersData = data["players"] as? [String: Any] else { return }
        if let foodArray = data["food_list"] as? [[Any]] {
            if allFood.children.isEmpty {
                addChild(allFood)
                createFood(foodArray.count)
            } else {
                updateFood(foodArray)
            }
        }

        // 更新排行榜
        updateRanking(playersData: playersData)
        
        // 更新现有玩家位置
        for (id, playerData) in playersData {
            guard let playerData = playerData as? [String: Any] else { return }
            if players[id] != nil {
                updatePlayer(id: id, playerData: playerData)
            }
        }
        playersCountLabel.text = "玩家: \(players.count)"
        
        // 移除已断开连接的玩家
        for (id, _) in players {
            if playersData[id] == nil {
                removePlayer(id: id)
                playersCountLabel.text = "玩家: \(players.count)"
            }
        }
    }
    
    private func sendMovementToServer() {
        guard let _ = myPlayerId, currentMovement != CGVector(dx: 0, dy: 0) else {
            return
        }
        
        let movementData: [String: Any] = [
            "type": "direction",
            "direction": [currentMovement.dx, currentMovement.dy]
        ]
        socketManager.sendData(movementData)
    }
    
    private func sendQuitGameToServer() {
        let quitGameData: [String: String] = [
            "type": "quit_game"
        ]
        socketManager.sendData(quitGameData)
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
    
    func sendUsernameToServer() {
        let usernameData: [String: Any] = [
            "type": "username",
            "username": "gagazh"
        ]
        socketManager.sendData(usernameData)
    }
    
    // MARK: - 处理UI布局
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard oldSize != size else { return }
        // 屏幕尺寸变化时重新计算边界
        calculateDisplayBounds()
        setupGameBorder()
        adjustUIPosition()
    }
    
    func adjustUIPosition() {
        guard let _ = statusLabel else { return }
        // 将UI元素移到边界内
        statusLabel.position = CGPoint(x: size.width / 2, y: size.height - 40)
        playersCountLabel.position = CGPoint(x: 30, y: size.height - 40)
        playerIdLabel.position = CGPoint(x: 100, y: size.height - 40)
        connectButton.position = CGPoint(x: size.width - 60, y: size.height - 40)
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
        currentMovement = CGVector(dx: cos(theta), dy: sin(theta))
    }
    
    // MARK: - 玩家管理
    func updatePlayer(id: String, playerData:[String: Any]) {
        guard let player = players[id] else {
            let player = SKNode(name: id)
            players[id] = player
            let idLabel = SKLabelNode(text: "玩家\(id)")
            idLabel.name = "玩家\(id)的标签"
            idLabel.fontSize = 15
            idLabel.fontName = "PingFangSC-Semibold"
            idLabel.fontColor = .white
            idLabel.zPosition = 109
            player.addChild(idLabel)
            addChild(player)
            return 
        }
        guard let snakeArray = playerData["snake"] as? [[CGFloat]], 
            let colorArray = playerData["color"] as? [Int], colorArray.count == 3, 
            let headRatio = playerData["head_ratio"] as? CGFloat, 
            let direction = playerData["direction"] as? [CGFloat],
            let playerTimesDict = playerData["effect_times"] as? [String: CGFloat],
            let name = playerData["name"] as? String else { return }
        let color = SKColor(red: CGFloat(colorArray[0])/255.0,
                          green: CGFloat(colorArray[1])/255.0,
                          blue: CGFloat(colorArray[2])/255.0,
                          alpha: 1.0)
        let playerAlpha: CGFloat = getAlphaFrom(playerTimesDict: playerTimesDict, totallyTransparent: id != myPlayerId)
        let playerSize = serverToScreenDistance(1) // 假设服务器端玩家大小为1
        let headX = snakeArray.first?[0] ?? -10
        let headY = snakeArray.first?[1] ?? -10
        let screenPosition = serverToScreenPosition(CGPoint(x: headX, y: headY + 1))
        if let idLabel = player.childNode(withName: "玩家\(id)的标签") as? SKLabelNode {
            // 更新玩家ID标签
            if idLabel.text == "玩家\(id)" {
                idLabel.text = myPlayerId == id ? "我" : name
            }
            let moveAction = SKAction.move(to: screenPosition, duration: updateInterval)
            idLabel.run(moveAction)
        }
        if player.children.count - 1 > snakeArray.count {
            for index in snakeArray.count ..< player.children.count - 1 {
                if let snakeBodyNode = player.childNode(withName: "蛇身节点\(index)") as? ColoredSpriteNode {
                    snakeBodyNode.isHidden = true
                }
            }
        }
        for (index, body) in snakeArray.enumerated() {
            let x = body[0]
            let y = body[1]
            let screenPosition = serverToScreenPosition(CGPoint(x: x, y: y))
            if index < player.children.count - 1 {
                // 把自身蛇头作为触摸位置指向的起始点
                if index == 0 && myPlayerId == id {
                    startPoint = screenPosition
                }
                // 重用蛇身节点
                guard let snakeBodyNode = player.childNode(withName: "蛇身节点\(index)") as? ColoredSpriteNode else { return }
                let ratio = snakeArray.count > 1 ? pow(Double(headRatio), 1 - Double(index) / Double(snakeArray.count - 1)) : headRatio
                let scaleAction = SKAction.scale(to: CGSize(width: ratio * playerSize, height: ratio * playerSize), duration: 1)
                let moveAction = SKAction.move(to: screenPosition, duration: updateInterval)
                let groupAction = SKAction.group([moveAction, scaleAction])
                snakeBodyNode.run(groupAction)
                if index == 0 {
                    // 按照服务器direction数据旋转蛇头
                    let angle = atan2(direction[1], direction[0])
                    snakeBodyNode.zRotation = angle
                    snakeBodyNode.glow(playerTimesDict: playerTimesDict)
                }
                snakeBodyNode.zPosition = 100 - CGFloat(index) / CGFloat(snakeArray.count)
                snakeBodyNode.isHidden = false
                snakeBodyNode.alpha = playerAlpha
            } else {
                let snakeBodyNode = index == 0 ? ColoredSpriteNode(texture: snakeHeadTexture) : ColoredSpriteNode(texture: snakeBodyTexture)
                snakeBodyNode.name = "蛇身节点\(index)"
                snakeBodyNode.setColorFromServer(color: color)
                snakeBodyNode.size = CGSize(width: playerSize, height: playerSize)
                snakeBodyNode.position = screenPosition
                player.addChild(snakeBodyNode)
                snakeBodyNode.zPosition = 100 - CGFloat(index) / CGFloat(snakeArray.count)
                snakeBodyNode.alpha = playerAlpha
            }
        }
    }
    
    func getAlphaFrom(playerTimesDict: [String: CGFloat], totallyTransparent: Bool) -> CGFloat {
        // 从玩家数据中获取当前显形、隐形时限
        guard let playerVisibleTime = playerTimesDict["显形"], let playerInvisibleTime = playerTimesDict["隐身"],
              let visibleTime = effectTimesDict["显形"], let invisibleTime = effectTimesDict["隐身"],
              let invisibleFactor = invisibleFactor else { return 1.0 }
        var alpha: CGFloat = 1
        if 0 < playerVisibleTime && playerVisibleTime <= visibleTime {
            alpha = min(1, 1 - playerVisibleTime / visibleTime)
        } else if playerInvisibleTime > invisibleTime / invisibleFactor {
            let enemyAlpha = max(0, 1 - (invisibleTime - playerInvisibleTime) * invisibleFactor / invisibleTime)
            alpha = !totallyTransparent && enemyAlpha < 0.2 ? 0.2 : enemyAlpha
        } else {
            let enemyAlpha = min(1, 1 - playerInvisibleTime / invisibleTime * invisibleFactor)
            alpha = !totallyTransparent && enemyAlpha < 0.2 ? 0.2 : enemyAlpha
        }
        return alpha
    }

    
    func removePlayer(id: String) {
        players[id]?.removeFromParent()
        players.removeValue(forKey: id)
        if let idLabel = childNode(withName: "玩家\(id)的标签") as? SKLabelNode {
            idLabel.removeFromParent()
        }
    }
    
    // MARK: 食物管理
    func createFood(_ foodCount: Int) {
        for _ in 0 ..< foodCount {
            let foodNode = SKSpriteNode(color: .clear, size: CGSize(width: 0, height: 0))
            allFood.addChild(foodNode)
        }
    }
    
    func updateFood(_ foodArray: [[Any]]) {
        if foodArray.count > allFood.children.count {
            createFood(foodArray.count - allFood.children.count)
        }
        if allFood.children.count > foodArray.count {
            for index in foodArray.count ..< allFood.children.count {
                allFood.children[index].isHidden = true
            }
        }
        let foodSize = serverToScreenDistance(1) // 假设服务器端食物大小为1
        for (index, food) in foodArray.enumerated() {
            guard let foodName = food[0] as? String else { return }
            guard let foodPos = food[1] as? [CGFloat] else { return }
            let x = foodPos[0]
            let y = foodPos[1]
            guard let foodNode = allFood.children[index] as? SKSpriteNode else { return }
            guard let index = foodTypes?[foodName]?["img_index"] as? Int else { return }
            foodNode.texture = foodTextures[index]
            foodNode.size = CGSize(width: foodSize, height: foodSize)
            let screenPosition = serverToScreenPosition(CGPoint(x: x, y: y))
            foodNode.position = screenPosition
            foodNode.isHidden = false
        }
    }
    
    // MARK: 排行榜管理
    func updateRanking(playersData: [String : Any]) {
        onlinePlayerId = playersData.keys
        ranking.children.forEach { $0.isHidden = true }
        ranking.children.filter { onlinePlayerId.contains($0.name) }.forEach { $0.isHidden = false}
        for (id, playerData) in playersData {
            guard let playerData = playerData as? [String: Any] else { return }
            guard let playerRanking = playerData["ranking"] as? Int,
                  var liveTime = playerData["live_time"] as? Double,
                  let alive = playerData["alive"] as? Bool,
                  let hp = playerData["hp"] as? Int,
                  let score = playerData["score"] as? Int,
                  let name = playerData["name"] as? String else { return }
            let status = alive ? "存活" : "死亡"
            liveTime = round(liveTime * 10) / 10
            let prefix = id == myPlayerId ? "->" : ""
            let text = "\(prefix)\(id)：\(name)(HP=\(hp))\(score)分 - \(status) \(liveTime)秒"
            if let rankLabel = ranking.childNode(withName: id) as? SKLabelNode {
                rankLabel.text = text
                moveAction = SKAction.move(to: CGPoint(x: 20, y: frame.height - 40 * CGFloat(playerRanking)), duration: 1)
                rankLabel.run(moveAction)
            } else {
                rankLabel = SKLabelNode()
                rankLabel.fontColor = .white
                rankLabel.fontName = "PingFangSC-Semibold"
                rankLabel.fontSize = 15
                rankLabel.zPosition = 110  // 最上层
                rankLabel.name = "排名标签\(id)"
                ranking.addChild(rankLabel)
            }
        } 
    }
}

// MARK: - 网络管理器代理
extension GameScene: GameSocketManagerDelegate {
    func didConnectToServer() {
        statusLabel.text = "已连接"
        statusLabel.fontColor = .green
        connected = true
    }
    
    func didDisconnectFromServer() {
        statusLabel.text = "连接断开"
        statusLabel.fontColor = .red
        connected = false
        
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
        case "game_event":
            handleGameEvent(data)
        case "game_state":
            gameState = data
        default:
            print("未知消息类型: \(type)")
        }
    }
}
