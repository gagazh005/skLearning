//
//  GameViewController.swift
//  skLearning
//
//  Created by 张欢 on 2025/9/14.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 在 GameViewController.swift 的 viewDidLoad 中添加调试代码
        let screen = UIScreen.main
        let screenSize = screen.bounds.size
        let scale = screen.scale
        let resolution = CGSize(width: screenSize.width * scale, height: screenSize.height * scale)
        let fixedSize = CGSize(width: 800, height: 600)

        print("屏幕尺寸（点）：\(screenSize.width) x \(screenSize.height)")
        print("屏幕缩放比例：\(scale)")
        print("屏幕分辨率（像素）：\(resolution.width) x \(resolution.height)")
        
        if let view = self.view as! SKView? {
            // 改为直接创建场景实例：
            let scene = GameScene(size: fixedSize)
            scene.scaleMode = .aspectFill
            
            // Set the scene coordinates (0, 0) to the center of the screen.
            // scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            
            // Present the scene
            view.presentScene(scene)
            view.ignoresSiblingOrder = true
            view.showsFPS = true
            view.showsNodeCount = true
            view.showsDrawCount = true
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
