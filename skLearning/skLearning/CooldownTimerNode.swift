import SpriteKit

class CooldownTimerNode: SKNode {
    private var backgroundCircle: SKShapeNode!
    private var maskNode: SKShapeNode!
    private var cropNode: SKCropNode!
    private var progressCircle: SKShapeNode!
    
    var name: String = ""
    var radius: CGFloat = 50
    var duration: TimeInterval = 5.0
    var isCoolingDown = false
    
    override init() {
        super.init()
        setupTimer()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupTimer()
    }
    
    private func setupTimer() {
        // 背景圆（灰色）
        backgroundCircle = SKShapeNode(circleOfRadius: radius)
        backgroundCircle.fillColor = .gray
        backgroundCircle.strokeColor = .darkGray
        backgroundCircle.lineWidth = 3
        addChild(backgroundCircle)
        
        // 进度圆（蓝色）
        progressCircle = SKShapeNode(circleOfRadius: radius)
        progressCircle.fillColor = .blue
        progressCircle.strokeColor = .clear
        
        // 裁剪节点
        cropNode = SKCropNode()
        cropNode.addChild(progressCircle)
        
        // 遮罩节点（初始为全遮罩）
        maskNode = SKShapeNode(rect: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        maskNode.fillColor = .black
        cropNode.maskNode = maskNode
        addChild(cropNode)

        // 名称标签
        statusLabel = SKLabelNode(text: name)
        statusLabel.position = CGPoint(x: -radius, y: -radius)
        statusLabel.fontColor = .red
        statusLabel.fontName = "PingFangSC-Semibold"
        statusLabel.fontSize = radius * 2
        addChild(statusLabel)
    }
    
    func startCooldown() {
        if isCoolingDown { return }
        
        isCoolingDown = true
        
        // 创建扇形路径动画
        let animateMask = SKAction.customAction(withDuration: duration) { [weak self] node, elapsedTime in
            guard let self = self else { return }
            
            let progress = elapsedTime / CGFloat(self.duration)
            let endAngle = CGFloat.pi * 2 * progress - CGFloat.pi / 2 // 从顶部开始
            
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addArc(withCenter: CGPoint.zero, radius: self.radius * 1.5, 
                       startAngle: -CGFloat.pi / 2, endAngle: endAngle, clockwise: true)
            path.close()
            
            if let mask = self.maskNode {
                mask.path = path.cgPath
            }
        }
        
        let completion = SKAction.run { [weak self] in
            self?.isCoolingDown = false
            self?.isHidden = true
        }
        
        let sequence = SKAction.sequence([animateMask, completion])
        maskNode.run(sequence)
    }
    
    func reset() {
        maskNode.removeAllActions()
        isCoolingDown = false
        
        // 重置为全遮罩
        let fullRect = SKShapeNode(rect: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
        maskNode.path = fullRect.path
    }
}