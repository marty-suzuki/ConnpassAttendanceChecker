//
//  UIViewController.extension.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit
import RxSwift

struct UIViewControllerExtension<Base: UIViewController> {
    let base: Base
}

protocol UIViewControllerCompatible {
    associatedtype Base: UIViewController
    var ex: UIViewControllerExtension<Base> { get }
}

extension UIViewControllerCompatible where Self: UIViewController {
    var ex: UIViewControllerExtension<Self> {
        return .init(base: self)
    }
}

extension UIViewController: UIViewControllerCompatible {}

extension UIViewControllerExtension {
    var topAnchor: NSLayoutYAxisAnchor {
        if #available(iOS 11, *) {
            return base.view.safeAreaLayoutGuide.topAnchor
        }
        return base.topLayoutGuide.bottomAnchor
    }

    var viewWillAppear: Observable<Bool> {
        return base.rx.methodInvoked(#selector(base.viewWillAppear(_:)))
            .flatMap { ($0.first as? Bool).map(Observable.just) ?? .empty() }
    }

    var viewDidAppear: Observable<Bool> {
        return base.rx.methodInvoked(#selector(base.viewDidAppear(_:)))
            .flatMap { ($0.first as? Bool).map(Observable.just) ?? .empty() }
    }
}
