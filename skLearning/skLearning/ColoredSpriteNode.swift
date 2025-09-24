import SpriteKit

class ColoredSpriteNode: SKSpriteNode {
    // 自定义颜色属性
    var customColor: SKColor = .white {
        didSet {
            updateColor()
        }
    }
    // 获取实际显示尺寸（考虑缩放）
    var actualSize: CGSize {
        return CGSize(width: size.width * xScale, height: size.height * yScale)
    }
    
    // 获取宽度的一半（常用于边界计算）
    var halfWidth: CGFloat {
        return (size.width * xScale) / 2
    }
    
    // 获取高度的一半
    var halfHeight: CGFloat {
        return (size.height * yScale) / 2
    }
    
    // 初始化
    init(texture: SKTexture?, color: UIColor = .white) {
        self.customColor = color
        super.init(texture: texture, color: .white, size: texture?.size() ?? .zero)
        setupShader()
        updateColor()
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
    
    func glow(playerTimesDict: [String: CGFloat]) {
        guard let glowNode = childNode(withName: "glow") as? SKShapeNode else {
            let glowNode = SKShapeNode(circleOfRadius: halfWidth)
            glowNode.name = "glow"
            glowNode.glowWidth = halfWidth
            glowNode.isHidden = true
            self.addChild(glowNode)
            return
        }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        customColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let complementaryColor = SKColor(red: 1.0 - red, green: 1.0 - green, blue: 1.0 - blue, alpha: 0.5)
        let transparentWhite = SKColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)
        if let powerTime = playerTimesDict["无敌"], let fieldTime = playerTimesDict["力场"] {
            if powerTime > 0 {
                glowNode.isHidden = false
                glowNode.strokeColor = complementaryColor
            } else if fieldTime > 0 {
                glowNode.isHidden = false
                glowNode.strokeColor = transparentWhite
            } else {
                glowNode.isHidden = true
            }
        }
    }
}
