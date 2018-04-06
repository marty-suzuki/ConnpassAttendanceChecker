//
//  UIAlertController.extension.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

enum AlertActionStyle {
    case `default`(String?)
    case cancel(String?)
    case destructive(String?)
}

extension AlertActionStyle {
    var style: UIAlertActionStyle {
        switch self {
        case .default: return .default
        case .cancel: return .cancel
        case .destructive: return .destructive
        }
    }

    var title: String? {
        switch self {
        case .default(let t): return t
        case .cancel(let t): return t
        case .destructive(let t): return t
        }
    }

    var isDefault: Bool {
        if case .default = self {
            return true
        }
        return false
    }

    var isCancel: Bool {
        if case .cancel = self {
            return true
        }
        return false
    }

    var isDestructive: Bool {
        if case .destructive = self {
            return true
        }
        return false
    }
}

extension UIViewControllerExtension where Base == UIAlertController {
    func show(with actions: [AlertActionStyle], to viewController: UIViewController) -> Observable<AlertActionStyle> {
        let observables = actions.map(add)
        viewController.present(base, animated: true, completion: nil)
        return Observable.merge(observables)
    }

    func add(action: AlertActionStyle) -> Observable<AlertActionStyle> {
        return Observable.create { [base] obsever in
            base.addAction(UIAlertAction(title: action.title, style: action.style, handler: { _ in
                obsever.onNext(action)
                obsever.onCompleted()
            }))
            return Disposables.create()
        }
    }
}
