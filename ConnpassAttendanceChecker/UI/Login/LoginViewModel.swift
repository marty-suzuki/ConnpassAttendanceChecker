//
//  LoginViewModel.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/08.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation
import WebKit
import RxSwift
import RxCocoa

final class LoginViewModel {
    private enum Const {
        static let dashboardURLString = "https://connpass.com/dashboard"
        static let loginURLString = "https://connpass.com/login"
    }

    let navigationActionPolicy: Observable<WKNavigationActionPolicy>
    let close: Observable<Void>
    let loadRequest: Observable<URLRequest>

    private let disposeBag = DisposeBag()

    init(navigationAction: Observable<WKNavigationAction>,
         closeButtonTap: Observable<Void>) {
        let _navigationActionPolicy = PublishRelay<WKNavigationActionPolicy>()
        self.navigationActionPolicy = _navigationActionPolicy.asObservable()
        let _close = PublishRelay<Void>()
        self.close = _close.asObservable()
        self.loadRequest = Observable.just(Const.loginURLString)
            .map { URL(string: $0).map { URLRequest(url: $0) } }
            .unwrap()
            .share(replay: 1, scope: .whileConnected)

        let navigationActionURL = navigationAction
            .map { $0.request.url }
            .share()

        let containsLoginURLString = navigationActionURL
            .unwrap()
            .map { $0.absoluteString.contains(Const.dashboardURLString) }
            .share()

        let policy = containsLoginURLString
            .map { contains -> WKNavigationActionPolicy in
                contains ? .cancel : .allow
            }

        let cancelPolicy = navigationActionURL
            .filter { $0 == nil }
            .map { _ in WKNavigationActionPolicy.cancel }

        Observable.merge(policy, cancelPolicy)
            .bind(to: _navigationActionPolicy)
            .disposed(by: disposeBag)

        let closeByURL = containsLoginURLString
            .filter { $0 }
            .map { _ in }

        Observable.merge(closeByURL, closeButtonTap)
            .bind(to: _close)
            .disposed(by: disposeBag)
    }
}
