//
//  DatabaseReference.extension.swift
//  ConnpassAttendanceChecker
//
//  Created by 鈴木大貴 on 2018/04/17.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation
import FirebaseDatabase
import RxSwift

extension Reactive where Base == DatabaseReference {
    func snapshot(for eventType: DataEventType) -> Observable<DataSnapshot> {
        return Observable.create { [base] observer in
            let handle = base.observe(eventType) { observer.onNext($0) }
            return Disposables.create {
                base.removeObserver(withHandle: handle)
            }
        }
    }
}
