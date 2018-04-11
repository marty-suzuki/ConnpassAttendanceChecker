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
    let loadRequest: Observable<URLRequest>
    let navigationActionPolicy: Observable<WKNavigationActionPolicy>
    let hideLoading: Observable<Bool>
    let enableRefresh: Observable<Bool>
    let showAlert: Observable<(AlertElement, ActionType)>

    private let disposeBag = DisposeBag()
    private let dataStore: EventDataStore

    init(viewDidAppear: Observable<Bool>,
         refreshButtonTap: Observable<Void>,
         logoutButtonTap: Observable<Void>,
         itemSelected: Observable<IndexPath>,
         navigationAction: Observable<WKNavigationAction>,
         didFinishNavigation: Observable<Void>,
         htmlDocument: Observable<HTMLDocument>,
         alertHandler: Observable<(AlertActionStyle, ActionType)>,
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

        let refresh = alertHandler
            .flatMap { style, action -> Observable<Void> in
                guard case .default = style, action == .refresh else {
                    return .empty()
                }
                return .just(())
            }

        let startFetching = Observable.merge(fetchEvents, refresh)
            .share()

        self.loadRequest = {
            let eventManageURLString = startFetching
                .map { _ in Const.eventManageURLString }

            let logoutURLString = alertHandler
                .flatMap { style, action -> Observable<String> in
                    guard case .destructive = style, action == .logout else {
                        return .empty()
                    }
                    return .just(Const.logoutURLString)
                }

            return Observable.merge(eventManageURLString, logoutURLString)
                .flatMap { URL(string: $0).map(Observable.just) ?? .empty() }
                .map { URLRequest(url: $0) }
                .share()
        }()

        self.navigationActionPolicy = navigationActionURL
            .map { _ in .allow }
            .share()

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

        navigationActionURL
            .map {
                $0.absoluteString.contains(Login.urlString) ||
                $0.absoluteString == Const.rootURLString
            }
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

