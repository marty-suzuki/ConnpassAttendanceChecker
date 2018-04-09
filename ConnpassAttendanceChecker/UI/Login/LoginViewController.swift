//
//  LoginViewController.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit
import WebKit
import RxSwift
import RxCocoa

final class LoginViewController: UIViewController {
    private let webview: WKWebView
    private let closeButton = UIBarButtonItem(title: "Close", style: .plain, target: nil, action: nil)
    private let loadingView = LoadingView(frame: .zero)

    private let _navigationAction = PublishRelay<WKNavigationAction>()
    private var navigationActionPolicyDisposeBag = DisposeBag()
    private let disposeBag = DisposeBag()
    private lazy var viewModel = LoginViewModel(navigationAction: self._navigationAction.asObservable(),
                                                closeButtonTap: self.closeButton.rx.tap.asObservable(),
                                                isLoading: self.webview.rx.loading)

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

        navigationItem.rightBarButtonItem = closeButton
        webview.navigationDelegate = self
        view.ex.addEdges(to: webview)

        loadingView.isHidden = true
        view.ex.addEdges(to: loadingView)

        viewModel.loadRequest
            .bind(to: Binder(webview) { webview, request in
                webview.load(request)
            })
            .disposed(by: disposeBag)

        viewModel.close
            .bind(to: Binder(self) { me, _ in
                me.dismiss(animated: true, completion: nil)
            })
            .disposed(by: disposeBag)

        viewModel.hideLoading
            .bind(to: loadingView.rx.isHidden)
            .disposed(by: disposeBag)
    }
}

extension LoginViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        navigationActionPolicyDisposeBag = DisposeBag()

        viewModel.navigationActionPolicy
            .bind(onNext: decisionHandler)
            .disposed(by: navigationActionPolicyDisposeBag)

        _navigationAction.accept(navigationAction)
    }
}
