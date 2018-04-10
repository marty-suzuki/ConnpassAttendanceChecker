//
//  RootViewController.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/10.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

final class RootViewController: UIViewController {
    private var currentViewController: UIViewController? {
        didSet {
            guard let currentViewController = currentViewController else { return }
            addChildViewController(currentViewController)
            view.ex.addEdges(to: currentViewController.view)
            currentViewController.didMove(toParentViewController: self)

            guard let oldViewController = oldValue else { return }
            view.sendSubview(toBack: currentViewController.view)
            UIView.transition(from: oldViewController.view,
                              to: currentViewController.view,
                              duration: 0.3,
                              options: .transitionCrossDissolve) { [weak oldViewController] _ in
                guard let oldViewController = oldViewController else { return }
                oldViewController.willMove(toParentViewController: nil)
                oldViewController.view.removeFromSuperview()
                oldViewController.removeFromParentViewController()
            }
        }
    }

    private let _loggedIn = PublishSubject<Void>()
    private let _loggedOut = PublishSubject<Void>()
    private lazy var viewModel = RootViewModel(loggedIn: self._loggedIn,
                                               loggedOut: self._loggedOut)
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel.showLogin
            .bind(to: Binder(self) { me, processPool in
                let vc = LoginViewController(processPool: processPool,
                                             loggedIn: me._loggedIn.asObserver())
                me.currentViewController = UINavigationController(rootViewController: vc)
            })
            .disposed(by: disposeBag)

        viewModel.showEventList
            .bind(to: Binder(self) { me, processPool in
                let vc = EventListViewController(processPool: processPool,
                                                 loggedOut: me._loggedOut.asObserver())
                me.currentViewController = UINavigationController(rootViewController: vc)
            })
            .disposed(by: disposeBag)
    }
}
