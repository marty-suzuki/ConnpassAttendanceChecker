//
//  LoginViewController.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit
import WebKit

final class LoginViewController: UIViewController {
    private let webview: WKWebView

    init(processPool: WKProcessPool) {
        self.webview = {
            let config = WKWebViewConfiguration()
            config.processPool = processPool
            return WKWebView(frame: .zero, configuration: config)
        }()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        webview.navigationDelegate = self
        view.ex.addEdges(to: webview)

        let url = URL(string: "https://connpass.com/login")!
        let request = URLRequest(url: url)
        webview.load(request)
    }
}

extension LoginViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print(navigationAction.request)
        // https://connpass.com/dashboard
        decisionHandler(.allow)
    }
}
