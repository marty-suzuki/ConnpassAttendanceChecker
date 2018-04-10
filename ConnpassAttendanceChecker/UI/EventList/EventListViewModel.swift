//
//  EventListViewModel.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import CoreData
import WebKit
import Kanna

final class EventListViewModel {
    private enum Const {
        static let eventManageURLString = "https://connpass.com/editmanage/"
    }

    let events: PropertyRelay<[Event]>
    let reloadData: Observable<Void>
    let selectedEvent: Observable<Event>
    let loadRequest: Observable<URLRequest>
    let navigationActionPolicy: Observable<WKNavigationActionPolicy>
    let hideLoading: Observable<Bool>
    let enableRefresh: Observable<Bool>

    private let disposeBag = DisposeBag()
    private let dataStore: EventDataStore

    init(viewDidAppear: Observable<Bool>,
         refreshButtonTap: Observable<Void>,
         itemSelected: Observable<IndexPath>,
         navigationAction: Observable<WKNavigationAction>,
         didFinishNavigation: Observable<Void>,
         htmlDocument: Observable<HTMLDocument>,
         isLoading: Observable<Bool>,
         loggedOut: AnyObserver<Void>,
         eventDataStore: EventDataStore? = nil) {
        let navigationActionURL = navigationAction
            .map { $0.request.url }
            .unwrap()
            .share()

        if let eventDataStore = eventDataStore {
            self.dataStore = eventDataStore
        } else {
            let doc = navigationActionURL
                .map { $0.absoluteString.contains(Const.eventManageURLString) }
                .flatMapFirst { contains in
                    contains ? htmlDocument : .empty()
                }
                .debug()

            self.dataStore = EventDataStore(htmlDocument: doc)
        }

        self.events = dataStore.events

        self.reloadData = events.skip(1).map { _ in }

        self.selectedEvent = itemSelected
            .withLatestFrom(events) { $1[$0.row] }
            .share()

        let fetchEvents = Observable.combineLatest(viewDidAppear, dataStore.events)
            .filter { $1.isEmpty }
            .map { _ in }

        let startFetching = Observable.merge(fetchEvents, refreshButtonTap)
            .share()

        self.loadRequest = startFetching
            .map { _ in Const.eventManageURLString }
            .flatMap { URL(string: $0).map(Observable.just) ?? .empty() }
            .map { URLRequest(url: $0) }
            .share()

        self.navigationActionPolicy = navigationActionURL
            .map { _ in .allow }
            .share()

        let _hideLoading = PublishRelay<Bool>()
        self.hideLoading = _hideLoading.asObservable()

        self.enableRefresh = Observable.combineLatest(dataStore.events, _hideLoading)
            .map { !$0.isEmpty && $1 }

        navigationActionURL
            .map { $0.absoluteString.contains(Login.urlString) }
            .filter { $0 }
            .map { _ in }
            .bind(to: loggedOut)
            .disposed(by: disposeBag)

        Observable.merge(startFetching.map { false },
                         dataStore.htmlUpdated.map { true })
            .bind(to: _hideLoading)
            .disposed(by: disposeBag)
    }
}

