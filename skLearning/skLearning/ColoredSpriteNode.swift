import SpriteKit

class ColoredSpriteNode: SKSpriteNode {
    // 自定义颜色属性
    var customColor: SKColor = .white {
        didSet {
            updateColor()
        }
    }

    override var size: CGSize = CGSize(width: 0, height: 0) {
        didSet {
            let width = size.width
            let sizes: [CGFloat] = [width + 120, width + 60, width + 30]
            let alphas: [CGFloat] = [0.3, 0.2, 0.1]
            guard let glowNode = childNode(withName: "glow") as? SKNode else { return }
            for i in 0..<sizes.count {
                if let circle = glowNode.childNode(withName: "circle\(i)") as? SKSpriteNode {
                    circle.radius = sizes[i]/2
                }
            }
        }
    }
    
    // 初始化
    init(texture: SKTexture?, color: UIColor = .white, isHead: Bool = false) {
        self.customColor = color
        super.init(texture: texture, color: .white, size: texture?.size() ?? .zero)
        setupShader()
        updateColor()
        if isHead {
            createGlow()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupShader()
    }
    
    // 设置着色器
    private func setupShader() {
        let shader = SKShader(source: """
        void main() {
            // 获取原始纹理颜色
            vec4 originalColor = texture2D(u_texture, v_tex_coord);
            
            // 转换为灰度（黑白）
            float gray = dot(originalColor.rgb, vec3(0.299, 0.587, 0.114));
            
            // 应用自定义颜色
            vec3 finalColor = vec3(gray) * customColor.rgb;
            
            // 输出最终颜色
            gl_FragColor = vec4(finalColor, originalColor.a);
        }
        """)
        
        // 添加自定义颜色 uniform
        shader.uniforms = [
            SKUniform(name: "customColor", vectorFloat4: vector_float4(1, 1, 1, 1))
        ]
        
        self.shader = shader
    }
    
    // 更新颜色
    private func updateColor() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        customColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let colorVector = vector_float4(Float(r), Float(g), Float(b), Float(a))
        (shader?.uniformNamed("customColor"))?.vectorFloat4Value = colorVector
    }
    
    // 根据服务器数据设置颜色
    func setColorFromServer(color: SKColor) {
        customColor = color
    }
    
    func setColorFromServer(r: Float, g: Float, b: Float, a: Float = 1.0) {
        customColor = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }

    func setAlphaFrom(playerTimesDict: [String: CGFloat], totallyTransparent: Bool) {
        // 从玩家数据中获取当前alpha值
        let invisibleFactor = self.invisibleFactor ?? 10
        if 0 < playerTimesDict["显形"] <= effectTimesDict["显形"] {
            alpha = min(1, 1 - playerTimesDict["显形"] / effectTimesDict["显形"])
        } else if playerTimesDict["隐身"] > effectTimesDict["隐身"] / invisibleFactor {
            enemyAlpha = max(0, 1 - (effectTimesDict["隐身"] - playerTimesDict["隐身"]) * invisibleFactor / effectTimesDict["隐身"])
            alpha = !totallyTransparent && enemyAlpha < 0.2? 0.2 : else enemyAlpha
        } else:
            enemyAlpha = min(1, 1 - playerTimesDict["隐身"] / effectTimesDict["隐身"] * invisibleFactor)
            alpha = !totallyTransparent && enemyAlpha < 0.2? 0.2 : else enemyAlpha
        self.alpha = alpha
    }

    func createGlow() {
        let glowNode = SKNode()
        glowNode.name = "glow"
        // 创建多层光晕
        let width = self.size.width
        let sizes: [CGFloat] = [width + 120, width + 60, width + 30]
        let alphas: [CGFloat] = [0.3, 0.2, 0.1]
        for i in 0..<sizes.count {
            let circle = SKShapeNode(circleOfRadius: sizes[i]/2)
            circle.name = "circle\(i)"
            circle.fillColor = .clear
            circle.strokeColor = .clear
            circle.alpha = alphas[i]
            circle.blendMode = .add
            glowNode.addChild(circle)
        }
        glowNode.isHidden = true
        self.addChild(glowNode)
    }

    func updateGlow(playerTimesDict: [String: CGFloat]) {
        guard let glowNode = childNode(withName: "glow") as? SKNode else { return }
        var color = customColor
        let complementaryColor = SKColor(red: 1.0 - color.red, green: 1.0 - color.green, blue: 1.0 - blue, alpha: color.alpha)
        if let powerTime = playerTimesDict["无敌"], let fieldTime = playerTimesDict["力场"] {
            if powerTime > 0 {
                glowNode.isHidden = false
                color = complementaryColor
            } else if fieldTime > 0 {
                glowNode.isHidden = false
                color = .white
            } else {
                glowNode.isHidden = true
            }
        }
        let alphas: [CGFloat] = [0.3, 0.2, 0.1]
        for i in 0..<alphas.count {
            if let circle = glowNode.childNode(withName: "circle\(i)") as? SKSpriteNode {
                circle.fillColor = color
                circle.alpha = alphas[i]
            }
        }
    }
}
