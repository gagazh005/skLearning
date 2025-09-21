import SpriteKit

class ColoredSpriteNode: SKSpriteNode {
    // 自定义颜色属性
    var customColor: SKColor = .white {
        didSet {
            updateColor()
        }
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
}
