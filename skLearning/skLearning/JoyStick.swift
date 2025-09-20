import SpriteKit

class JoyStick: SKNode {
    // 方向盘组件
    private let base: SKShapeNode  // 底座
    private let stick: SKShapeNode // 控制杆
    
    // 配置参数
    private let baseRadius: CGFloat
    private let stickRadius: CGFloat
    private let stickRange: CGFloat  // 控制杆移动范围
    
    // 状态
    var isActive = false
    var currentAngle: CGFloat = 0    // 角度（弧度）
    var intensity: CGFloat = 0       // 强度（0-1）
    
    // 方向变化回调
    var onDirectionChanged: ((CGFloat, CGFloat) -> Void)? // 角度，强度
    
    init(baseRadius: CGFloat = 60, stickRadius: CGFloat = 20) {
        self.baseRadius = baseRadius
        self.stickRadius = stickRadius
        self.stickRange = baseRadius - stickRadius
        
        // 创建底座
        base = SKShapeNode(circleOfRadius: baseRadius)
        base.fillColor = UIColor(white: 0.2, alpha: 0.5)
        base.strokeColor = UIColor(white: 0.8, alpha: 0.8)
        base.lineWidth = 2
        base.zPosition = 10
        
        // 创建控制杆
        stick = SKShapeNode(circleOfRadius: stickRadius)
        stick.fillColor = UIColor(white: 0.9, alpha: 0.9)
        stick.strokeColor = UIColor.white
        stick.lineWidth = 1
        base.zPosition = 10
        
        super.init()
        
        setupNodes()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupNodes() {
        // 添加底座和控制杆
        addChild(base)
        addChild(stick)
        
        // 设置初始位置
        stick.position = .zero
        
        // 启用用户交互
        isUserInteractionEnabled = true
    }
    
    // MARK: - 触摸处理
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 检查触摸是否在底座范围内
        if base.contains(location) {
            isActive = true
            updateStickPosition(location)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isActive, let touch = touches.first else { return }
        let location = touch.location(in: self)
        updateStickPosition(location)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetStick()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        resetStick()
    }
    
    // MARK: - 控制杆更新
    
    private func updateStickPosition(_ position: CGPoint) {
        // 计算相对于中心的位置向量
        let vector = CGVector(dx: position.x, dy: position.y)
        let distance = min(sqrt(vector.dx * vector.dx + vector.dy * vector.dy), stickRange)
        
        // 计算角度（弧度）
        currentAngle = atan2(vector.dy, vector.dx)
        
        // 计算强度（0-1）
        intensity = distance / stickRange
        
        // 更新控制杆位置
        let angle = currentAngle
        stick.position = CGPoint(
            x: cos(angle) * distance,
            y: sin(angle) * distance
        )
        
        // 触发回调
        onDirectionChanged?(currentAngle, intensity)
    }
    
    private func resetStick() {
        isActive = false
        intensity = 0
        
        // 平滑复位动画
        let resetAction = SKAction.move(to: .zero, duration: 0.2)
        resetAction.timingMode = .easeOut
        stick.run(resetAction)
        
        // 通知方向重置
        onDirectionChanged?(0, 0)
    }
    
    // MARK: - 工具方法
    
    /// 获取方向向量（归一化）
    func getDirectionVector() -> CGVector {
        return CGVector(dx: cos(currentAngle), dy: sin(currentAngle))
    }
    
    /// 获取角度（度数）
    func getAngleInDegrees() -> CGFloat {
        return currentAngle * 180 / .pi
    }
    
    /// 设置方向盘位置（屏幕左下角）
    func positionInLowerLeftCorner(of scene: SKScene) {
        position = CGPoint(x: baseRadius + 20, y: baseRadius + 20)
    }
}
