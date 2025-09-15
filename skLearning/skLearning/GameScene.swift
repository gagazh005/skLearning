import SpriteKit

class GameScene: SKScene {
    var currentLine: SKShapeNode?  // 当前绘制的直线
    var currentCircle: SKShapeNode?  // 当前绘制的圆圈
    private let snakeHeadNode = SKSpriteNode(imageNamed: "snakeHead")
    private var joyStick: JoyStick!
    var startPoint: CGPoint?      // 起点位置
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupJoyStick()
        snakeHeadNode.scale(to: CGSize(width: 50, height: 50))
        snakeHeadNode.position = CGPoint(x: frame.midX, y: frame.midY)
        snakeHeadNode.name = "蛇头"
        startPoint = snakeHeadNode.position
        addChild(snakeHeadNode)
        
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
        let direction = joyStick.getDirectionVector()
        if intensity > 0.5 {
            snakeHeadNode.zRotation = angle
        }
        print("方向向量=\(direction)")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let startPoint = startPoint else { return }
        if let _ = currentCircle, let _ = currentLine { return }
        let location = touch.location(in: self)
        
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
}
