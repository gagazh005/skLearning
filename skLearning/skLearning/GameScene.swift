// GameScene.swift
import SpriteKit

class GameScene: SKScene {
    
    override func didMove(to view: SKView) {
        // 设置场景背景色
        backgroundColor = SKColor.black
        
        // 添加欢迎标签
        let welcomeLabel = SKLabelNode(text: "点击屏幕添加方块!")
        welcomeLabel.position = CGPoint(x: frame.midX, y: frame.midY)
        welcomeLabel.fontSize = 24
        addChild(welcomeLabel)
        
        // 2秒后淡出欢迎标签
        let fadeOut = SKAction.fadeOut(withDuration: 1.0)
        let wait = SKAction.wait(forDuration: 2.0)
        welcomeLabel.run(SKAction.sequence([wait, fadeOut]))
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // 创建随机颜色的方块
        let box = SKSpriteNode(color: randomColor(), size: CGSize(width: 50, height: 50))
        box.position = location
        box.name = "box"
        
        // 添加物理体
        box.physicsBody = SKPhysicsBody(rectangleOf: box.size)
        box.physicsBody?.restitution = 0.5 // 弹性
        
        // 添加一些旋转效果
        let rotate = SKAction.rotate(byAngle: CGFloat.pi * 2, duration: 2.0)
        box.run(SKAction.repeatForever(rotate))
        
        addChild(box)
    }
    
    // 生成随机颜色
    func randomColor() -> UIColor {
        let red = CGFloat.random(in: 0...1)
        let green = CGFloat.random(in: 0...1)
        let blue = CGFloat.random(in: 0...1)
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
    
    // 摇晃设备时清除所有方块
    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            removeAllBoxes()
        }
    }
    
    func removeAllBoxes() {
        for node in children where node.name == "box" {
            node.removeFromParent()
        }
    }
}
