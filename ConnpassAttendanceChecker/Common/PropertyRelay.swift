//
//  PropertyRelay.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import RxCocoa
import RxSwift

final class PropertyRelay<Element>: ObservableType {
    typealias E = Element

    private let relay: BehaviorRelay<E>

    var value: E {
        return relay.value
    }

    init(_ relay: BehaviorRelay<E>) {
        self.relay = relay
    }

    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, E == O.E {
        return relay.subscribe(observer)
    }

    func asObservable() -> Observable<E> {
        return relay.asObservable()
    }
}
