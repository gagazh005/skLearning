//
//  AppDelegate.swift
//  skLearning
//
//  Created by 张欢 on 2025/9/14.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        print("App 启动开始 - 无 Storyboard 模式")
        
        // 创建窗口
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = .black // 游戏应用通常用黑色背景
        
        // 设置根视图控制器
        setupRootViewController()
        
        window?.makeKeyAndVisible()
        
        print("App 启动完成")
        return true
    }
    
    private func setupRootViewController() {
        // 检查登录状态
        if isUserLoggedIn() {
            showGameViewController()
        } else {
            showLoginViewController()
        }
    }
    
    private func isUserLoggedIn() -> Bool {
        let serverIP = UserDefaults.standard.string(forKey: "lastServerIP")
        let username = UserDefaults.standard.string(forKey: "lastUsername")
        let isLoggedIn = serverIP != nil && username != nil
        
        print("登录状态检查: \(isLoggedIn ? "已登录" : "未登录")")
        return isLoggedIn
    }
    
    func showLoginViewController() {
        let loginVC = LoginViewController()
        
        // 设置登录成功回调
        loginVC.onLoginSuccess = { [weak self] in
            self?.showGameViewController()
        }
        
        // 切换根视图控制器
        switchRootViewController(to: loginVC, animated: true)
        print("切换到登录界面")
    }
    
    func showGameViewController() {
        let gameVC = GameViewController()
        switchRootViewController(to: gameVC, animated: true)
        print("切换到游戏界面")
    }
    
    private func switchRootViewController(to newViewController: UIViewController, animated: Bool = true) {
        guard let window = self.window else { return }
        
        if animated {
            // 添加转场动画
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
                let oldState = UIView.areAnimationsEnabled
                UIView.setAnimationsEnabled(false)
                window.rootViewController = newViewController
                UIView.setAnimationsEnabled(oldState)
            }, completion: nil)
        } else {
            window.rootViewController = newViewController
        }
    }

    // 其他方法保持不变...
    func applicationWillResignActive(_ application: UIApplication) {
        print("应用将进入非活动状态")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("应用进入后台")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("应用将进入前台")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        print("应用已激活")
    }
}
