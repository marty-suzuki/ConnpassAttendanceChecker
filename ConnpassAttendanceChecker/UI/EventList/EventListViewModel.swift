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
        static let logoutURLString = "https://connpass.com/logout/"
        static let rootURLString = "https://connpass.com/"
    }

    enum ActionType {
        case logout
        case refresh
    }

    let events: PropertyRelay<[Event]>
    let reloadData: Observable<Void>
    let selectedEvent: Observable<Event>
    let hideLoading: Observable<Bool>
    let enableRefresh: Observable<Bool>
    let showAlert: Observable<(AlertElement, ActionType)>

    private let disposeBag = DisposeBag()
    private let dataStore: EventDataStoreType
    private let webhook: WebhookViewType

    init<Webhook: WebhookViewType, DataStore: EventDataStoreType>
        (processPool: WKProcessPool,
         viewWillAppear: Observable<Bool>,
         refreshButtonTap: Observable<Void>,
         logoutButtonTap: Observable<Void>,
         itemSelected: Observable<IndexPath>,
         alertHandler: Observable<(AlertActionStyle, ActionType)>,
         loggedOut: AnyObserver<Void>,
         webhookType: Webhook.Type,
         dataStoreType: DataStore.Type,
         database: Database = .shared) {
        let _loadRequet = PublishRelay<URLRequest>()
        let _navigationActionPolicy = PublishRelay<WKNavigationActionPolicy>()

        self.webhook = Webhook(processPool: processPool,
                               loadRequet: _loadRequet.asObservable(),
                               navigationActionPolicy: _navigationActionPolicy.asObservable())

        let navigationActionURL = webhook.navigationAction
            .map { $0.request.url }
            .unwrap()
            .share()

        let htmlDocument = navigationActionURL
            .map { $0.absoluteString.contains(Const.eventManageURLString) }
            .flatMapFirst { [webhook] contains in
                contains ? webhook.htmlDocument : .empty()
            }

        let deleteAll = alertHandler
            .flatMap { style, action -> Observable<Void> in
                guard case .destructive = style, action == .logout else {
                    return .empty()
                }
                return .just(())
            }
            .share()

        self.dataStore = DataStore(htmlDocument: htmlDocument,
                                   deleteAll: deleteAll,
                                   database: database)

        self.events = dataStore.events
        self.reloadData = events.skip(1).map { _ in }

        self.selectedEvent = itemSelected
            .withLatestFrom(events) { $1[$0.row] }
            .share()

        let fetchEvents = Observable.combineLatest(viewWillAppear, dataStore.events)
            .filter { $1.isEmpty }
            .map { _ in }

        let refresh = alertHandler
            .flatMap { style, action -> Observable<Void> in
                guard case .default = style, action == .refresh else {
                    return .empty()
                }
                return .just(())
            }

        let startFetching = Observable.merge(fetchEvents, refresh)
            .share()

        do {
            let eventManageURLString = startFetching
                .map { _ in Const.eventManageURLString }

            let logoutURLString = dataStore.allDeleted
                .map { _ in Const.logoutURLString }

            Observable.merge(eventManageURLString, logoutURLString)
                .flatMap { URL(string: $0).map(Observable.just) ?? .empty() }
                .map { URLRequest(url: $0) }
                .bind(to: _loadRequet)
                .disposed(by: disposeBag)
        }

        navigationActionURL
            .map { _ in .allow }
            .bind(to: _navigationActionPolicy)
            .disposed(by: disposeBag)

        let _hideLoading = PublishRelay<Bool>()
        self.hideLoading = _hideLoading.asObservable()

        self.enableRefresh = Observable.combineLatest(dataStore.events, _hideLoading)
            .map { !$0.isEmpty && $1 }

        self.showAlert = {
            let logout = logoutButtonTap
                .map { _ -> (AlertElement, ActionType) in
                    (AlertElement(title: "Logout",
                                  message: "Do you want logout?",
                                  actions: [.destructive("Logout"), .cancel("Cancel")]),
                     .logout)
                }
            let refresh = refreshButtonTap
                .map { _ -> (AlertElement, ActionType) in
                    (AlertElement(title: "Refresh",
                                  message: "Do you want refresh event list?",
                                  actions: [.default("Refresh"), .cancel("Cancel")]),
                     .refresh)
                }
            return Observable.merge(logout, refresh)
        }()

        let receiveLoggedoutURL = navigationActionURL
            .map {
                $0.absoluteString.contains(Login.urlString) ||
                $0.absoluteString == Const.rootURLString
            }
            .filter { $0 }
            .map { _ in }
            .share()

        receiveLoggedoutURL
            .bind(to: loggedOut)
            .disposed(by: disposeBag)

        Observable.merge(startFetching.map { false },
                         dataStore.htmlUpdated.map { true },
                         deleteAll.map { false },
                         receiveLoggedoutURL.map { true })
            .bind(to: _hideLoading)
            .disposed(by: disposeBag)
    }
}

