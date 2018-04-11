//
//  WebhookView.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/11.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit
import WebKit
import RxSwift
import RxCocoa
import Kanna

protocol WebhookViewType: class {
    var navigationAction: Observable<WKNavigationAction> { get }
    var didFinishNavigation: Observable<Void> { get }
    var htmlDocument: Observable<HTMLDocument> { get }
    var isLoading: Observable<Bool> { get }

    init(processPool: WKProcessPool,
         loadRequet: Observable<URLRequest>,
         navigationActionPolicy: Observable<WKNavigationActionPolicy>)
}

final class WebhookView: NSObject, WebhookViewType {
    var view: UIView {
        return webview
    }

    let navigationAction: Observable<WKNavigationAction>
    let didFinishNavigation: Observable<Void>
    let htmlDocument: Observable<HTMLDocument>
    let isLoading: Observable<Bool>

    private let webview: WKWebView

    private let _didFinishNavigation = PublishRelay<Void>()
    private let _navigationAction = PublishRelay<WKNavigationAction>()

    private let navigationActionPolicy: Observable<WKNavigationActionPolicy>

    private var navigationActionPolicyDisposeBag = DisposeBag()
    private let disposeBag = DisposeBag()

    init(processPool: WKProcessPool,
         loadRequet: Observable<URLRequest>,
         navigationActionPolicy: Observable<WKNavigationActionPolicy>) {
        let config = WKWebViewConfiguration()
        config.processPool = processPool
        self.webview = WKWebView(frame: .zero, configuration: config)
        self.navigationActionPolicy = navigationActionPolicy
        self.navigationAction = _navigationAction.asObservable()
        self.didFinishNavigation = _didFinishNavigation.asObservable()

        let _htmlDocument = PublishRelay<HTMLDocument>()
        self.htmlDocument = _htmlDocument.asObservable()

        self.isLoading = webview.rx.loading

        super.init()

        webview.navigationDelegate = self

        _didFinishNavigation
            .flatMapFirst { [weak webview] in
                webview.map { $0.rx.html() } ?? .empty()
            }
            .bind(to: _htmlDocument)
            .disposed(by: disposeBag)

        loadRequet
            .bind(to: Binder(webview) {
                $0.load($1)
            })
            .disposed(by: disposeBag)
    }
}

extension WebhookView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        navigationActionPolicyDisposeBag = DisposeBag()

        navigationActionPolicy
            .bind(onNext: decisionHandler)
            .disposed(by: navigationActionPolicyDisposeBag)

        _navigationAction.accept(navigationAction)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        _didFinishNavigation.accept(())
    }
}
