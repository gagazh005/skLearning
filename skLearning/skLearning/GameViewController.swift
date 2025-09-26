// 修改后的 GameViewController.swift
import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    
    private var hasShownLogin = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 在 GameViewController.swift 的 viewDidLoad 中添加调试代码
        let screen = UIScreen.main
        let screenSize = screen.bounds.size
        let scale = screen.scale
        let resolution = CGSize(width: screenSize.width * scale, height: screenSize.height * scale)
        
        print("屏幕尺寸（点）：\(screenSize.width) x \(screenSize.height)")
        print("屏幕缩放比例：\(scale)")
        print("屏幕分辨率（像素）：\(resolution.width) x \(resolution.height)")
        
        // 先显示登录界面
        showLoginViewController()
    }
    
    private func showLoginViewController() {
        let loginVC = LoginViewController()
        loginVC.modalPresentationStyle = .fullScreen
        
        // 设置登录成功回调
        loginVC.onLoginSuccess = { [weak self] in
            self?.startGame()
        }
        
        present(loginVC, animated: false) {
            self.hasShownLogin = true
        }
    }
    
    private func startGame() {
        let screen = UIScreen.main
        let screenSize = screen.bounds.size
        
        if let view = self.view as! SKView? {
            // 创建游戏场景
            let scene = GameScene(size: screenSize)
            scene.scaleMode = .resizeFill
            
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