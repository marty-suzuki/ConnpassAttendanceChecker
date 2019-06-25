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

    private let relay: BehaviorRelay<Element>

    var value: Element {
        return relay.value
    }

    init(_ relay: BehaviorRelay<Element>) {
        self.relay = relay
    }

    init(_ value: Element) {
        self.relay = BehaviorRelay(value: value)
    }

    func subscribe<O>(_ observer: O) -> Disposable where O : ObserverType, Element == O.Element {
        return relay.subscribe(observer)
    }

    func asObservable() -> Observable<Element> {
        return relay.asObservable()
    }
}
