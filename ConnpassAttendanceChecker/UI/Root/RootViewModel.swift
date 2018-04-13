//
//  RootViewModel.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/10.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import WebKit

final class RootViewModel {
    let showLogin: Observable<WKProcessPool>
    let showEventList: Observable<WKProcessPool>

    private let _processPool: BehaviorRelay<WKProcessPool>
    private let _isLoggedIn: BehaviorRelay<Bool>
    private let userDefaults: UserDefaultsType
    private let disposeBag = DisposeBag()

    init(loggedIn: Observable<Void>,
         loggedOut: Observable<Void>,
         processPool: WKProcessPool = .init(),
         userDefaults: UserDefaultsType = UserDefaults.standard) {
        self.userDefaults = userDefaults
        self._processPool = BehaviorRelay(value: processPool)
        self._isLoggedIn = BehaviorRelay(value: userDefaults.ex.isLoggedIn)
        self.showLogin = _isLoggedIn
            .filter { !$0 }
            .withLatestFrom(_processPool)
        self.showEventList = _isLoggedIn
            .filter { $0 }
            .withLatestFrom(_processPool)

        Observable.merge(loggedIn .map { _ in true },
                         loggedOut.map { _ in false })
            .bind(to: _isLoggedIn)
            .disposed(by: disposeBag)

        _isLoggedIn
            .skip(1)
            .subscribe(onNext: { [weak userDefaults] in
                var ex = userDefaults?.ex
                ex?.isLoggedIn = $0
            })
            .disposed(by: disposeBag)
    }
}
