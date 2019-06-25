//
//  ObservableType.unwrap.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//


import Foundation
import RxSwift

public protocol OptionalType {
    associatedtype Wrapped
    var value: Wrapped? { get }
}

extension Optional: OptionalType {
    public var value: Wrapped? {
        return self
    }
}

extension ObservableType where Element: OptionalType {
    public func unwrap() -> Observable<Element.Wrapped> {
        return flatMap {
            $0.value.map(Observable.just) ?? .empty()
        }
    }
}
