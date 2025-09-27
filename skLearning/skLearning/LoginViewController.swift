//
//  LoginViewController.swift
//  skLearning
//
//  Created by 张欢 on 2025/9/14.
//

import UIKit

class LoginViewController: UIViewController {
    
    // 登录成功回调
    var onLoginSuccess: (() -> Void)?
    var serverIP: String?
    var username: String?
    
    // UI 组件
    private var serverIPTextField: UITextField!
    private var usernameTextField: UITextField!
    private var loginButton: UIButton!
    private var exitButton: UIButton!
    private var titleLabel: UILabel!
    private var containerView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        setupUI()
        loadLastLoginInfo()
        
        print("LoginViewController 加载完成（纯代码版）")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("LoginViewController 已显示")
    }
    
    private func setupUI() {
        createUIComponents()
        setupConstraints()
        setupActions()
    }
    
    private func createUIComponents() {
        // 容器视图
        containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // 标题标签
        titleLabel = UILabel()
        titleLabel.text = "游戏登录"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // 服务器IP输入框
        serverIPTextField = UITextField()
        serverIPTextField.placeholder = "服务器IP"
        serverIPTextField.borderStyle = .roundedRect
        serverIPTextField.keyboardType = .URL
        serverIPTextField.autocapitalizationType = .none
        serverIPTextField.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(serverIPTextField)
        
        // 用户名输入框
        usernameTextField = UITextField()
        usernameTextField.placeholder = "用户名"
        usernameTextField.borderStyle = .roundedRect
        usernameTextField.autocapitalizationType = .none
        usernameTextField.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(usernameTextField)
        
        // 登录按钮
        loginButton = UIButton(type: .system)
        loginButton.setTitle("登录", for: .normal)
        loginButton.backgroundColor = .systemBlue
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.layer.cornerRadius = 8
        loginButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(loginButton)
        
        // 退出按钮
        exitButton = UIButton(type: .system)
        exitButton.setTitle("退出", for: .normal)
        exitButton.setTitleColor(.systemRed, for: .normal)
        exitButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(exitButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 容器约束
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            // 标题约束
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // 服务器IP输入框约束
            serverIPTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            serverIPTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            serverIPTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            serverIPTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // 用户名输入框约束
            usernameTextField.topAnchor.constraint(equalTo: serverIPTextField.bottomAnchor, constant: 20),
            usernameTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            usernameTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            usernameTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // 登录按钮约束
            loginButton.topAnchor.constraint(equalTo: usernameTextField.bottomAnchor, constant: 30),
            loginButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            loginButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            loginButton.heightAnchor.constraint(equalToConstant: 50),
            
            // 退出按钮约束
            exitButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 15),
            exitButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            exitButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    private func setupActions() {
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        exitButton.addTarget(self, action: #selector(exitTapped), for: .touchUpInside)
        
        // 点击背景收起键盘
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    private func loadLastLoginInfo() {
        if let lastServerIP = UserDefaults.standard.string(forKey: "lastServerIP") {
            serverIPTextField.text = lastServerIP
        } else {
            serverIPTextField.text = "192.168.1.100"
        }
        
        if let lastUsername = UserDefaults.standard.string(forKey: "lastUsername") {
            usernameTextField.text = lastUsername
        } else {
            usernameTextField.text = "玩家"
        }
    }
    
    @objc private func loginTapped() {
        guard let serverIP = serverIPTextField.text, !serverIP.isEmpty else {
            showAlert(message: "请输入服务器IP")
            return
        }
        
        guard let username = usernameTextField.text, !username.isEmpty else {
            showAlert(message: "请输入用户名")
            return
        }
        
        loginButton.isEnabled = false
        loginButton.setTitle("登录中...", for: .normal)
        
        handleLogin(serverIP: serverIP, username: username)
    }
    
    @objc private func exitTapped() {
        exit(0)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func handleLogin(serverIP: String, username: String) {
        print("登录中 - 服务器: \(serverIP), 用户名: \(username)")
        
        // 保存登录信息
        UserDefaults.standard.set(serverIP, forKey: "lastServerIP")
        UserDefaults.standard.set(username, forKey: "lastUsername")
        
        self.serverIP = serverIP
        self.username = username
        
        // 执行回调
        onLoginSuccess?()
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
