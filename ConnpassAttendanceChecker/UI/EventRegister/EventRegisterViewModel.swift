//
//  EventRegisterViewModel.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation
import RxSwift
import CoreData

final class EventRegisterViewModel {
    let closeKeyboad: Observable<Void>
    let loadRequest: Observable<URLRequest>
    let showAlert: Observable<String>
    let close: Observable<Void>

    init(cancelButtonTap: Observable<Void>,
         doneButtonTap: Observable<Void>,
         closeButtonTap: Observable<Void>,
         textFeildValue: Observable<String?>,
         isLoading: Observable<Bool>,
         title: Observable<String?>,
         actionStyle: Observable<AlertActionStyle>,
         database: Database = .shared) {
        let doneWithText =  doneButtonTap
            .withLatestFrom(textFeildValue.unwrap())
            .filter { !$0.isEmpty }
            .share()

        self.closeKeyboad = Observable.merge(cancelButtonTap, doneWithText.map { _ in })

        self.loadRequest = doneWithText
            .flatMap {
                URL(string: "https://connpass.com/event/\($0)")
                    .map { Observable.just(URLRequest(url: $0)) } ?? .empty()
            }

        self.showAlert = isLoading
            .skip(1)
            .filter { !$0 }
            .map { _ in "Do you register this event?" }

        let _title = title.unwrap()

        let finishSaving = actionStyle
            .filter { $0.isDefault }
            .withLatestFrom(doneWithText)
            .flatMap { Int64($0).map(Observable.just) ?? .empty() }
            .withLatestFrom(_title) { ($0, $1) }
            .flatMap { id, title in
                database.perform(block: { context in
                    let model = StoredEvent(context: context)
                    model.id = id
                    model.title = title
                })
            }

        self.close = Observable.merge(closeButtonTap, finishSaving)
    }
}
