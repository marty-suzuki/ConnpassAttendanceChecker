//
//  ParticipantListViewModel.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import WebKit
import RxSwift
import RxRelay
import Kanna
import CoreData
import UIKit

final class ParticipantListViewModel {
    private enum Const {
        static let loginURLString = "https://connpass.com/login"
    }

    struct CheckedAlertElement {
        let index: Int
        let title: String
        let message: String
        let actions: [AlertActionStyle]
        let isChecked: Bool
    }

    enum SearchType: CaseIterable {
        case number
        case name
    }

    let event: Event
    let participants: PropertyRelay<[Participant]>

    let reloadData: Observable<Void>
    let closeKeyboard: Observable<Void>
    let showCheckedAlert: Observable<CheckedAlertElement>
    let scrollTo: Observable<IndexPath>
    let clearSearchText: Observable<Void>
    let selectorTitle: Observable<String>
    let searchTypes: Observable<[SearchType]>
    let showPicker: Observable<Void>
    let hidePicker: Observable<Void>
    let keyboardType: Observable<UIKeyboardType>
    let deselectIndexPath: Observable<IndexPath>
    let hideLoading: Observable<Bool>
    let showDetail: Observable<Void>

    let refresh: AnyObserver<Void>
    private let _refresh = PublishSubject<Void>()

    private let _searchTypes = BehaviorRelay<[SearchType]>(value: SearchType.allCases)
    private let _displayParticipants = BehaviorRelay<[Participant]>(value: [])
    private let _searchType = BehaviorRelay<SearchType>(value: .number)
    private let disposeBag = DisposeBag()
    private let dataStore: ParticipantDataStoreType
    private let webhook: WebhookViewType

    init<Webhook: WebhookViewType, DataStore: ParticipantDataStoreType>
        (event: Event,
         processPool: WKProcessPool,
         viewWillAppear: Observable<Bool>,
         searchText: Observable<String?>,
         cancelButtonTap: Observable<Void>,
         searchButtonTap: Observable<Void>,
         selectorButtonTap: Observable<Void>,
         detailButtonTap: Observable<Void>,
         checkedActionStyle: Observable<AlertActionStyle>,
         pickerItemSelected: Observable<(row: Int, component: Int)>,
         tableViewItemSelected: Observable<IndexPath>,
         loggedOut: AnyObserver<Void>,
         webhookType: Webhook.Type,
         dataStoreType: DataStore.Type,
         database: DatabaseType = Database.shared) {
        self.event = event
        self.showDetail = detailButtonTap
        self.refresh = _refresh.asObserver()

        let _loadRequet = PublishRelay<URLRequest>()
        let _navigationActionPolicy = PublishRelay<WKNavigationActionPolicy>()

        let _participantsURL = PublishRelay<URL>()
        _participantsURL
            .map { URLRequest(url: $0) }
            .bind(to: _loadRequet)
            .disposed(by: disposeBag)

        self.webhook = Webhook(processPool: processPool,
                               loadRequet: _loadRequet.asObservable(),
                               navigationActionPolicy: _navigationActionPolicy.asObservable())

        let _hideLoading = PublishRelay<Bool>()
        self.hideLoading = _hideLoading.asObservable()

        let _showCheckedAlert = PublishRelay<CheckedAlertElement>()
        self.showCheckedAlert = _showCheckedAlert.asObservable()

        let textWithSeachType = searchText
            .unwrap()
            .withLatestFrom(_searchType) { ($0, $1) }
            .share(replay: 1, scope: .whileConnected)

        let navigationActionURL = webhook.navigationAction
            .map { $0.request.url }
            .share()

        do {
            let updateChehckedWithIndex = checkedActionStyle
                .filter { $0.isDefault }
                .withLatestFrom(_showCheckedAlert)
                .map { (!$0.isChecked, $0.index) }

            let name = textWithSeachType
                .filter { $1 == .name  && !$0.isEmpty }
                .map { $0.0 }

            let number = textWithSeachType
                .filter { $1 == .number && !$0.isEmpty }
                .flatMap { Int($0.0).map(Observable.just) ?? .empty() }

            let participant = tableViewItemSelected
                .withLatestFrom(_displayParticipants) { $1[$0.row] }

            let htmlDocument = navigationActionURL
                .unwrap()
                .withLatestFrom(_participantsURL) { ($0, $1) }
                .map { $0.absoluteString.contains($1.absoluteString) }
                .flatMapFirst { [webhook] contains in
                    contains ? webhook.htmlDocument : .empty()
                }

            self.dataStore = DataStore(event: event,
                                       htmlDocument: htmlDocument,
                                       updateChehckedWithIndex: updateChehckedWithIndex,
                                       filterWithNunmber: number,
                                       filterWithName: name,
                                       indexOfParticipant: participant,
                                       database: database)
        }

        self.participants = PropertyRelay(_displayParticipants)
        self.searchTypes = _searchTypes.asObservable()
        self.selectorTitle = _searchType
            .map { "\(String.ex.localized(.searchType)): \($0.title)" }
        self.keyboardType = _searchType
            .map { $0.keyboardType }

        let _scrollTo = PublishRelay<IndexPath>()
        self.scrollTo = _scrollTo.asObservable()

        let _clearSearchText = PublishRelay<Void>()
        self.clearSearchText = _clearSearchText.asObservable()

        self.reloadData = _displayParticipants
            .map { _ in }

        self.deselectIndexPath = checkedActionStyle
            .filter { $0.isDestructive }
            .withLatestFrom(tableViewItemSelected)

        self.showPicker = selectorButtonTap
        self.hidePicker = _searchType.map { _ in }.skip(1)

        let _closeKeyboard = PublishRelay<Void>()
        self.closeKeyboard = _closeKeyboard.asObservable()

        dataStore.participants
            .bind(to: _displayParticipants)
            .disposed(by: disposeBag)

        pickerItemSelected
            .withLatestFrom(_searchTypes) { $1[$0.row] }
            .bind(to: _searchType)
            .disposed(by: disposeBag)

        do {
            let filteredParticipants = textWithSeachType
                .filter { $0.0.isEmpty }
                .withLatestFrom(dataStore.participants)

            Observable.merge(filteredParticipants,
                             dataStore.filteredParticipants)
                .bind(to: _displayParticipants)
                .disposed(by: disposeBag)
        }

        dataStore.indexAndParticipant
            .map(CheckedAlertElement.init)
            .bind(to: _showCheckedAlert)
            .disposed(by: disposeBag)

        do {
            let containsLoginURLString = navigationActionURL
                .unwrap()
                .map { $0.absoluteString.contains(Const.loginURLString) }
                .share()

            let policy = containsLoginURLString
                .map { contains -> WKNavigationActionPolicy in
                    contains ? .cancel : .allow
                }

            let cancelPolicy = navigationActionURL
                .filter { $0 == nil }
                .map { _ in WKNavigationActionPolicy.cancel }

            Observable.merge(policy, cancelPolicy)
                .bind(to: _navigationActionPolicy)
                .disposed(by: disposeBag)

            containsLoginURLString
                .filter { $0 }
                .map { _ in }
                .bind(to: loggedOut)
                .disposed(by: disposeBag)
        }

        do {
            let updatedWithIndexPath = dataStore.updatedIndex
                .map { IndexPath(row: $0, section: 0) }
                .share()

            updatedWithIndexPath
                .map { _ in }
                .bind(to: _clearSearchText)
                .disposed(by: disposeBag)

            updatedWithIndexPath
                .bind(to: _scrollTo)
                .disposed(by: disposeBag)

            Observable.merge(cancelButtonTap,
                             selectorButtonTap,
                             searchButtonTap,
                             updatedWithIndexPath.map { _ in })
                .bind(to: _closeKeyboard)
                .disposed(by: disposeBag)
        }

        do {
            let fetchParticipants = Observable.combineLatest(viewWillAppear, dataStore.participants)
                .filter { $1.isEmpty }
                .map { _ in }

            let startFetching = Observable.merge(fetchParticipants, _refresh)
                .share()

            startFetching
                .map { [event] in URL(string: "https://connpass.com/event/\(event.id)/participants/") }
                .unwrap()
                .bind(to: _participantsURL)
                .disposed(by: disposeBag)

            Observable.merge(startFetching.map { false },
                             dataStore.htmlUpdated.map { true })
                .bind(to: _hideLoading)
                .disposed(by: disposeBag)
        }
    }
}

extension ParticipantListViewModel.CheckedAlertElement {
    fileprivate init(index: Int, participant: Participant) {
        let ex = String.ex
        let strings = [
            "\(ex.localized(.number)): \(participant.number)",
            "\(ex.localized(.displayName)): \(participant.displayName)",
            "\(ex.localized(.userName)): \(participant.userName)",
            "\(ex.localized(.pType)): \(participant.ptype)"
        ]
        let string = "\(ex.localized(.check))\(ex.localized(participant.isChecked ? .out : .in))"
        self.index = index
        self.title = String(format: ex.localized(.doYouThisParticipant), string)
        self.message = String(strings.joined(separator: "\n"))
        self.isChecked = participant.isChecked
        self.actions = [.default(string), .destructive(ex.localized(.cancel))]
    }
}

extension ParticipantListViewModel.SearchType {
    var title: String {
        let ex = String.ex
        switch self {
        case .number: return ex.localized(.number)
        case .name: return "\(ex.localized(.userName)) \(ex.localized(.or)) \(ex.localized(.displayName))"
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .number: return .numberPad
        case .name: return .default
        }
    }
}
