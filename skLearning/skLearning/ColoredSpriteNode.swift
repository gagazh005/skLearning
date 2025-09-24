import SpriteKit

class ColoredSpriteNode: SKSpriteNode {
    
    var customColor: SKColor = .white {
        didSet {
            // 使用SpriteKit内置的颜色混合，而不是自定义uniform
            self.color = customColor
            self.colorBlendFactor = 1.0
        }
    }
    
    var actualSize: CGSize {
        return CGSize(width: size.width * xScale, height: size.height * yScale)
    }
    
    var halfWidth: CGFloat { return (size.width * xScale) / 2 }
    var halfHeight: CGFloat { return (size.height * yScale) / 2 }
    
    init(texture: SKTexture?, color: UIColor = .white) {
        self.customColor = color
        super.init(texture: texture, color: .white, size: texture?.size() ?? .zero)
        setupShader()
        self.color = color
        self.colorBlendFactor = 1.0
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupShader()
    }
    
    private func setupShader() {
        let shader = SKShader(source: """
        void main() {
            // 获取原始纹理颜色
            vec4 tex_color = texture2D(u_texture, v_tex_coord);
            
            // 转换为灰度（使用亮度加权，符合人眼感知）
            float gray = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
            
            // 应用颜色混合（v_color_mix是SpriteKit自动提供的混合颜色）
            vec3 final_rgb = vec3(gray) * v_color_mix.rgb;
            
            // 保持透明度
            gl_FragColor = vec4(final_rgb, tex_color.a * v_color_mix.a);
        }
        """)
        
        self.shader = shader
    }
    
    // 移除updateShaderColor方法，因为现在使用SpriteKit的颜色混合
    
    func setColorFromServer(color: SKColor) {
        customColor = color
    }
    
    func setColorFromServer(r: Float, g: Float, b: Float, a: Float = 1.0) {
        customColor = SKColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }
    
    func glow(playerTimesDict: [String: CGFloat]) {
        guard let glowNode = childNode(withName: "glow") as? SKShapeNode else {
            let glowNode = SKShapeNode(circleOfRadius: halfWidth)
            glowNode.name = "glow"
            glowNode.fillColor = .clear
            glowNode.glowWidth = halfWidth
            glowNode.isHidden = true
            self.addChild(glowNode)
            return
        }
        
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard customColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            glowNode.isHidden = true
            return
        }
        if let powerTime = playerTimesDict["无敌"], powerTime > 0 {
            let complementaryColor = SKColor(red: 1.0 - red, green: 1.0 - green, blue: 1.0 - blue, alpha: 1.0)
            glowNode.isHidden = false
            glowNode.strokeColor = complementaryColor
            glowNode.alpha = 0.5
        } else if let fieldTime = playerTimesDict["力场"], fieldTime > 0 {
            glowNode.isHidden = false
            glowNode.strokeColor = .white
            glowNode.alpha = 0.5
        } else {
            glowNode.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 0, duration: 1),
                SKAction.run { glowNode.isHidden = true }
            ]))
        }
    }
}
