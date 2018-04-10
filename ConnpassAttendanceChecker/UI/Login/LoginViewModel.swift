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

enum Login {
    static let urlString = "https://connpass.com/login"
}

final class LoginViewModel {
    private enum Const {
        static let dashboardURLString = "https://connpass.com/dashboard"
    }

    let navigationActionPolicy: Observable<WKNavigationActionPolicy>
    let loadRequest: Observable<URLRequest>
    let hideLoading: Observable<Bool>

    private let disposeBag = DisposeBag()

    init(navigationAction: Observable<WKNavigationAction>,
         isLoading: Observable<Bool>,
         loggedIn: AnyObserver<Void>) {
        self.hideLoading = isLoading.map { !$0 }
        let _navigationActionPolicy = PublishRelay<WKNavigationActionPolicy>()
        self.navigationActionPolicy = _navigationActionPolicy.asObservable()
        self.loadRequest = Observable.just(Login.urlString)
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

        containsLoginURLString
            .filter { $0 }
            .map { _ in }
            .bind(to: loggedIn)
            .disposed(by: disposeBag)
    }
}
