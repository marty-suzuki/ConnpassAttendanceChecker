//
//  ParticipantListDetailViewModel.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/12.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

final class ParticipantListDetailViewModel {
    enum Row: Enumerable {
        case counts
        case refresh
        case export
    }

    let close: Observable<Void>

    let rows = PropertyRelay<[Row]>(Row.elements)

    let checkInCount: PropertyRelay<Int>
    private let _checkInCount = BehaviorRelay<Int>(value: 0)

    let participantCount: PropertyRelay<Int>
    private let _participantCount = BehaviorRelay<Int>(value: 0)

    private let disposeBag = DisposeBag()

    init(childViewModel: ParticipantListViewModel,
         closeButtonTap: Observable<Void>) {
        self.close = closeButtonTap
        self.checkInCount = PropertyRelay(_checkInCount)
        self.participantCount = PropertyRelay(_participantCount)

        childViewModel.participants
            .map { $0.lazy.filter { $0.isChecked }.count }
            .bind(to: _checkInCount)
            .disposed(by: disposeBag)

        childViewModel.participants
            .map { $0.count }
            .bind(to: _participantCount)
            .disposed(by: disposeBag)
    }
}
