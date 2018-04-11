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
    private let webview: WebhookView
    private let loadingView = LoadingView(frame: .zero)

    private let _loadRequest: PublishRelay<URLRequest>
    private let _navigationActionPolicy: PublishRelay<WKNavigationActionPolicy>
    private let _loggedIn: AnyObserver<Void>
    private let disposeBag = DisposeBag()
    private lazy var viewModel = LoginViewModel(navigationAction: self.webview.navigationAction,
                                                isLoading: self.webview.isLoading,
                                                loggedIn: self._loggedIn)

    init(processPool: WKProcessPool, loggedIn: AnyObserver<Void>) {
        let loadRequest = PublishRelay<URLRequest>()
        let navigationActionPolicy = PublishRelay<WKNavigationActionPolicy>()
        self.webview = WebhookView(processPool: processPool,
                              loadRequet: loadRequest.asObservable(),
                              navigationActionPolicy: navigationActionPolicy.asObservable())
        self._loadRequest = loadRequest
        self._navigationActionPolicy = navigationActionPolicy
        self._loggedIn = loggedIn
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.ex.addEdges(to: webview.view)

        loadingView.isHidden = true
        view.ex.addEdges(to: loadingView)

        viewModel.loadRequest
            .bind(to: _loadRequest)
            .disposed(by: disposeBag)

        viewModel.hideLoading
            .bind(to: loadingView.rx.isHidden)
            .disposed(by: disposeBag)

        viewModel.navigationActionPolicy
            .bind(to: _navigationActionPolicy)
            .disposed(by: disposeBag)
    }
}
