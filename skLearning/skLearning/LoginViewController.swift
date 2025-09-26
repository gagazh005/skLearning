// LoginViewController.swift
import UIKit

class LoginViewController: UIViewController {
    
    // 回调闭包，登录成功后执行
    var onLoginSuccess: (() -> Void)?
    
    private let serverIPTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "服务器IP"
        textField.borderStyle = .roundedRect
        textField.keyboardType = .URL
        textField.autocapitalizationType = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let usernameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "用户名"
        textField.borderStyle = .roundedRect
        textField.autocapitalizationType = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("登录", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let exitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("退出", for: .normal)
        button.setTitleColor(.systemRed, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "游戏登录"
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        
        // 设置默认值用于测试
        serverIPTextField.text = "192.168.1.100"
        usernameTextField.text = "玩家"
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(serverIPTextField)
        containerView.addSubview(usernameTextField)
        containerView.addSubview(loginButton)
        containerView.addSubview(exitButton)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: serverIPTextField.topAnchor, constant: -30),
            
            serverIPTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            serverIPTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            serverIPTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            serverIPTextField.heightAnchor.constraint(equalToConstant: 44),
            
            usernameTextField.topAnchor.constraint(equalTo: serverIPTextField.bottomAnchor, constant: 20),
            usernameTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            usernameTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            usernameTextField.heightAnchor.constraint(equalToConstant: 44),
            
            loginButton.topAnchor.constraint(equalTo: usernameTextField.bottomAnchor, constant: 30),
            loginButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            loginButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            loginButton.heightAnchor.constraint(equalToConstant: 50),
            
            exitButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 15),
            exitButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            exitButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
    
    private func setupActions() {
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        exitButton.addTarget(self, action: #selector(exitTapped), for: .touchUpInside)
        
        // 添加点击背景收起键盘
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
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
        
        // 模拟登录过程
        loginButton.isEnabled = false
        loginButton.setTitle("登录中...", for: .normal)
        
        // 模拟网络请求延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.handleLoginSuccess(serverIP: serverIP, username: username)
        }
    }
    
    @objc private func exitTapped() {
        exit(0)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func handleLoginSuccess(serverIP: String, username: String) {
        print("登录成功 - 服务器: \(serverIP), 用户名: \(username)")
        
        // 保存登录信息（可选）
        UserDefaults.standard.set(serverIP, forKey: "lastServerIP")
        UserDefaults.standard.set(username, forKey: "lastUsername")
        
        // 执行回调并关闭登录界面
        dismiss(animated: true) {
            self.onLoginSuccess?()
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}