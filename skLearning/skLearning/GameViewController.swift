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
    
    private var pinchGesture: UIPinchGestureRecognizer!
    private var rotationGesture: UIRotationGestureRecognizer!
    private var swipeUpGesture: UISwipeGestureRecognizer!
    private var skView: SKView!
    private var scene: GameScene!

    override func loadView() {
        // 手动创建 SKView 作为主视图
        skView = SKView()
        self.view = skView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("GameViewController 加载完成")
        let screen = UIScreen.main
        let screenSize = screen.bounds.size
        let scale = screen.scale
        let resolution = CGSize(width: screenSize.width * scale, height: screenSize.height * scale)
        
        //print("屏幕尺寸（点）：\(screenSize.width) x \(screenSize.height)")
        //print("屏幕缩放比例：\(scale)")
        //print("屏幕分辨率（像素）：\(resolution.width) x \(resolution.height)")
        
        // 现在直接使用 skView，不需要强制转换
        scene = GameScene(size: screenSize)
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
        skView.showsDrawCount = true
        
        // 添加捏合手势识别器
        setupPinchGesture()
        setupRotationGesture()
        setupSwipeUpGesture()
        
        // 添加提示标签（可选，可以在一段时间后隐藏）
        showHintLabel()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("GameViewController 已显示在窗口层级中")
    }
    
    private func setupPinchGesture() {
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        pinchGesture.delegate = self
        view.addGestureRecognizer(pinchGesture)
        print("捏合手势已添加")
    }

    private func setupRotationGesture() {
        rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotationGesture(_:)))
        rotationGesture.delegate = self
        view.addGestureRecognizer(rotationGesture)
        print("旋转手势已添加")
    }
    
    private func setupSwipeUpGesture() {
        swipeUpGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUpGesture(_:)))
        swipeUpGesture.direction = .up
        swipeUpGesture.numberOfTouchesRequired = 3 // 三指上推
        swipeUpGesture.delegate = self
        view.addGestureRecognizer(swipeUpGesture)
        print("三指上推手势已添加")
    }

    @objc private func handleRotationGesture(_ gesture: UIRotationGestureRecognizer) {
        switch gesture.state {
        case .began:
            print("旋转手势开始，旋转角度: \(gesture.rotation)")
            
        case .changed:
            let rotation = gesture.rotation
            let degrees = rotation * 180 / .pi
            print("旋转中: \(String(format: "%.1f", degrees))°")
            
        case .ended, .cancelled:
            handleRotationGestureEnded(gesture)
            
        default:
            break
        }
    }
    
    @objc private func handleSwipeUpGesture(_ gesture: UISwipeGestureRecognizer) {
        guard gesture.state == .ended else { return }
        
        print("三指上推手势触发")
        handleThreeFingerSwipeUp()
    }
    
    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            // 手势开始，可以添加一些视觉反馈
            print("捏合手势开始，缩放比例: \(gesture.scale)")
            
        case .changed:
            // 手势进行中，可以实时显示缩放比例
            break
            
        case .ended, .cancelled:
            // 手势结束，检查是否满足返回条件
            checkPinchForReturn(gesture)
            
        default:
            break
        }
    }
    
    // MARK: - 手势结束处理
    private func checkPinchForReturn(_ gesture: UIPinchGestureRecognizer) {
        let scale = gesture.scale
        let velocity = gesture.velocity
        
        // 返回条件：缩放比例小于0.5（捏合）且速度较快，或者缩放比例大于2.0（张开）
        let isPinchIn = scale < 0.5 && velocity < -1.0
        let isPinchOut = scale > 2.0 && velocity > 1.0
        
        if isPinchIn || isPinchOut {
            print("满足返回条件: 缩放比例=\(scale), 速度=\(velocity)")
            showReturnConfirmation()
        } else {
            print("不满足返回条件: 缩放比例=\(scale), 速度=\(velocity)")
        }
    }
    
    private func showReturnConfirmation() {
        // 创建确认弹窗
        let alert = UIAlertController(
            title: "返回登录界面",
            message: "确定要返回登录界面吗？",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self] _ in
            self?.returnToLogin()
        }))
        
        present(alert, animated: true)
    }
    
    private func returnToLogin() {
        print("返回登录界面")
        
        // 清除登录信息
        UserDefaults.standard.removeObject(forKey: "lastServerIP")
        UserDefaults.standard.removeObject(forKey: "lastUsername")

        scene.processQuitGame()
        
        // 通过 AppDelegate 切换回登录界面
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.showLoginViewController()
        } else {
            // 备用方案：如果 AppDelegate 方法不可用，使用 dismiss
            dismiss(animated: true) {
                print("已返回到登录界面")
            }
        }
    }

    private func handleRotationGestureEnded(_ gesture: UIRotationGestureRecognizer) {
        let rotation = gesture.rotation
        let velocity = gesture.velocity
        let degrees = rotation * 180 / .pi
        
        print("旋转手势结束: 角度=\(String(format: "%.1f", degrees))°, 速度=\(velocity)")
        
        // 根据旋转角度和速度执行不同操作
        if abs(degrees) > 30 && abs(velocity) > 1.0 {
            // 快速旋转超过30度
            if degrees > 0 {
                showGestureAlert("顺时针快速旋转", message: "重生")
                scene.processReborn()
            } else {
                showGestureAlert("逆时针快速旋转", message: "换颜色")
                scene.processChangeColor()
            }
        } else if abs(degrees) > 180 {
            showGestureAlert("旋转一圈", message: "执行空白动作B")
        }
    }

    private func handleThreeFingerSwipeUp() {
        // 三指上推的功能
        showGestureAlert("三指上推", message: "暂停/恢复游戏")
        scene.processPauseGame()
    }

    private func showGestureAlert(_ title: String, message: String) {
        // 简单的提示，不打断游戏
        print("手势动作: \(title) - \(message)")
        
        // 可以在游戏界面上显示一个临时提示
        showTemporaryMessage("\(title): \(message)")
    }
    
    private func showTemporaryMessage(_ message: String) {
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.textColor = .white
        messageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        messageLabel.textAlignment = .center
        messageLabel.font = UIFont.systemFont(ofSize: 16)
        messageLabel.layer.cornerRadius = 8
        messageLabel.clipsToBounds = true
        messageLabel.alpha = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            messageLabel.heightAnchor.constraint(equalToConstant: 40),
            messageLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40)
        ])
        
        // 显示动画
        UIView.animate(withDuration: 0.3) {
            messageLabel.alpha = 1
        }
        
        // 2秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UIView.animate(withDuration: 0.3, animations: {
                messageLabel.alpha = 0
            }) { _ in
                messageLabel.removeFromSuperview()
            }
        }
    } 

    private func showHintLabel() {
        // 添加一个临时提示标签，3秒后自动隐藏
        let hintLabel = UILabel()
        hintLabel.text = "双指捏合可返回登录界面，三指上推暂停游戏，顺时针快速旋转重生"
        hintLabel.textColor = .white
        hintLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        hintLabel.textAlignment = .center
        hintLabel.font = UIFont.systemFont(ofSize: 14)
        hintLabel.layer.cornerRadius = 8
        hintLabel.clipsToBounds = true
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(hintLabel)
        
        NSLayoutConstraint.activate([
            hintLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.heightAnchor.constraint(equalToConstant: 30),
            hintLabel.widthAnchor.constraint(equalToConstant: 200)
        ])
        
        // 3秒后淡出隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            UIView.animate(withDuration: 0.5, animations: {
                hintLabel.alpha = 0
            }) { _ in
                hintLabel.removeFromSuperview()
            }
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

// 实现手势识别器代理，允许同时识别其他手势
extension GameViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 允许捏合手势与其他手势同时识别，不影响游戏操作
        return true
    }
}
