//
//  ParticipantListViewModel.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation
import WebKit
import RxSwift
import RxCocoa
import Kanna
import CoreData
import UIKit

final class ParticipantListViewModel: NSObject {
    private enum Const {
        static let loginURLString = "https://connpass.com/login"
    }

    struct CheckedAlertElement {
        let index: Int
        let title: String
        let message: String
    }

    enum SearchType: Enumerable {
        case number
        case name
    }

    let processPool: PropertyRelay<WKProcessPool>
    let participants: PropertyRelay<[Participant]>

    let reloadData: Observable<Void>
    let participantsURL: Observable<URL>
    let navigationActionPolicy: Observable<WKNavigationActionPolicy>
    let showLogin: Observable<WKProcessPool>
    let getHTMLDocument: Observable<Void>
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

    private let _searchTypes = BehaviorRelay<[SearchType]>(value: SearchType.elements)
    private let _displayParticipants = BehaviorRelay<[Participant]>(value: [])
    private let _participants: BehaviorRelay<[Participant]>
    private let _searchType = BehaviorRelay<SearchType>(value: .number)
    private let disposeBag = DisposeBag()
    private let fetchedResultsController: NSFetchedResultsController<StoredParticipant>

    init(event: Event,
         viewDidAppear: Observable<Bool>,
         navigationAction: Observable<WKNavigationAction>,
         htmlDocument: Observable<HTMLDocument>,
         loading: Observable<Bool>,
         searchText: Observable<String?>,
         cancelButtonTap: Observable<Void>,
         searchButtonTap: Observable<Void>,
         selectorButtonTap: Observable<Void>,
         checkedActionStyle: Observable<AlertActionStyle>,
         pickerItemSelected: Observable<(row: Int, component: Int)>,
         tableViewItemSelected: Observable<IndexPath>,
         processPool: WKProcessPool = .init(),
         database: Database = .shared) {
        let request: NSFetchRequest<StoredParticipant> = StoredParticipant.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "number", ascending: false)]
        self.fetchedResultsController = database.makeFetchedResultsController(fetchRequest: request)
        try? fetchedResultsController.performFetch()
        let results = fetchedResultsController.fetchedObjects ?? []
        self._participants = BehaviorRelay(value: results.map(Participant.init))
        self.participants = PropertyRelay(_displayParticipants)
        self.searchTypes = _searchTypes.asObservable()
        self.selectorTitle = _searchType
            .map { "Search Type: \($0.title)" }
        self.keyboardType = _searchType
            .map { $0.keyboardType }

        let _processPool = BehaviorRelay(value: processPool)
        self.processPool = PropertyRelay(_processPool)

        let _participantsURL = BehaviorRelay<URL?>(value: nil)
        self.participantsURL = _participantsURL.unwrap()

        let _navigationActionPolicy = PublishRelay<WKNavigationActionPolicy>()
        self.navigationActionPolicy = _navigationActionPolicy.asObservable()

        let _showLogin = PublishRelay<WKProcessPool>()
        self.showLogin = _showLogin.asObservable()

        let _getHTMLDocument = PublishRelay<Void>()
        self.getHTMLDocument = _getHTMLDocument.asObservable()

        let _showCheckedAlert = PublishRelay<CheckedAlertElement>()
        self.showCheckedAlert = _showCheckedAlert.asObservable()

        let _scrollTo = PublishRelay<IndexPath>()
        self.scrollTo = _scrollTo.asObservable()

        let _clearSearchText = PublishRelay<Void>()
        self.clearSearchText = _clearSearchText.asObservable()

        self.reloadData = _displayParticipants
            .map { _ in }

        self.deselectIndexPath = checkedActionStyle
            .filter { $0.isDestructive }
            .withLatestFrom(_showCheckedAlert.map { $0.index })
            .map { IndexPath(row: $0, section: 0) }

        self.showPicker = selectorButtonTap
        self.hidePicker = _searchType.map { _ in }.skip(1)

        let _closeKeyboard = PublishRelay<Void>()
        self.closeKeyboard = _closeKeyboard.asObservable()

        _participants
            .bind(to: _displayParticipants)
            .disposed(by: disposeBag)

        pickerItemSelected
            .withLatestFrom(_searchTypes) { $1[$0.row] }
            .bind(to: _searchType)
            .disposed(by: disposeBag)

        let textWithSeachType = searchText
            .unwrap()
            .withLatestFrom(_searchType) { ($0, $1) }
            .share(replay: 1, scope: .whileConnected)

        let filteredParticipants1 = textWithSeachType
            .filter { $1 == .number && !$0.isEmpty }
            .flatMap { Int($0.0).map(Observable.just) ?? .empty() }
            .withLatestFrom(_participants) { ($0, $1) }
            .map { number, participants in
                participants.filter { "\($0.number)".contains("\(number)") }
            }

        let filteredParticipants2 = textWithSeachType
            .filter { $1 == .name  && !$0.isEmpty }
            .withLatestFrom(_participants) { ($0.0, $1) }
            .map { name, participants in
                participants.filter {
                    let name = name.lowercased()
                    return $0.userName.lowercased().contains(name) ||
                        $0.displayName.lowercased().contains(name)
                }
            }

        let filteredParticipants3 = textWithSeachType
            .filter { $0.0.isEmpty }
            .withLatestFrom(_participants)

        Observable.merge(filteredParticipants1,
                         filteredParticipants2,
                         filteredParticipants3)
            .bind(to: _displayParticipants)
            .disposed(by: disposeBag)

        tableViewItemSelected
            .withLatestFrom(_displayParticipants) { ($0.row, $1) }
            .withLatestFrom(_participants) { ($0.0, $0.1, $1) }
            .flatMap { index, displayParticipants, participants -> Observable<CheckedAlertElement> in
                let participant = displayParticipants[index]
                let strings = [
                    "Number: \(participant.number)",
                    "DisplayName: \(participant.displayName)",
                    "UserName: \(participant.userName)"
                ]
                let message = String(strings.joined(separator: "\n"))
                guard let index = participants.index(where: {
                    $0.number == participant.number &&
                    $0.userName == participant.userName &&
                    $0.displayName == participant.displayName
                }) else {
                    return .empty()
                }
                return .just(CheckedAlertElement(index: index,
                                                 title: "Do you check in this participant?",
                                                 message: message))
            }
            .bind(to: _showCheckedAlert)
            .disposed(by: disposeBag)

        htmlDocument
            .map { [event] in Participant.list(from: $0, eventID: event.id) }
            .flatMap { participants -> Single<Void> in
                database.perform(block: { context in
                    participants.forEach { participant in
                        let model = StoredParticipant(context: context)
                        model.number = Int64(participant.number)
                        model.ptype = participant.ptype
                        model.displayName = participant.displayName
                        model.userName = participant.userName
                        model.eventID = Int64(participant.eventID)
                    }
                })
            }
            .subscribe()
            .disposed(by: disposeBag)

        let updatedWithIndexPath = checkedActionStyle
            .filter { $0.isDefault }
            .withLatestFrom(_showCheckedAlert.map { $0.index })
            .withLatestFrom(_participants) { ($0, $1) }
            .flatMap { index, participants -> Observable<IndexPath> in
                let participant = participants[index]
                return database.perform(block: { context in
                    let request: NSFetchRequest<StoredParticipant> = StoredParticipant.fetchRequest()
                    request.fetchLimit = 1
                    request.predicate = NSPredicate(format: "number = %lld AND eventID = %lld",
                                                    participant.number,
                                                    participant.eventID)

                    guard let object = try context.fetch(request).first else {
                        throw Database.Error.objectNotFound
                    }

                    object.isChecked = true
                })
                .asObservable()
                .catchError { _ in .empty() }
                .map { IndexPath(row: index, section: 0) }
            }
            .share()

        updatedWithIndexPath
            .map { _ in }
            .bind(to: _clearSearchText)
            .disposed(by: disposeBag)

        updatedWithIndexPath
            .bind(to: _scrollTo)
            .disposed(by: disposeBag)

        let navigationActionURL = navigationAction
            .map { $0.request.url }
            .share()

        let containsLoginURLString = navigationActionURL
            .unwrap()
            .map { $0.absoluteString.contains(Const.loginURLString) }
            .share()

        do {
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
                .withLatestFrom(_processPool)
                .bind(to: _showLogin)
                .disposed(by: disposeBag)
        }

        let containgParticipantsURLString = navigationActionURL
            .unwrap()
            .withLatestFrom(_participantsURL.unwrap()) { ($0, $1) }
            .filter { $0.absoluteString.contains($1.absoluteString) }
            .map { _ in }

        Observable.combineLatest(loading,
                                 containsLoginURLString,
                                 containgParticipantsURLString)
            .filter { !$0.0 && !$0.1 }
            .map { _ in }
            .bind(to: _getHTMLDocument)
            .disposed(by: disposeBag)

        let fetchParticipants = Observable.combineLatest(viewDidAppear, _participants)
            .filter { $1.isEmpty }
            .map { _ in }

        fetchParticipants
            .map { [event] in URL(string: "https://connpass.com/event/\(event.id)/participants") }
            .bind(to: _participantsURL)
            .disposed(by: disposeBag)

        Observable.merge(cancelButtonTap,
                         selectorButtonTap,
                         searchButtonTap,
                         updatedWithIndexPath.map { _ in })
            .bind(to: _closeKeyboard)
            .disposed(by: disposeBag)

        super.init()

        fetchedResultsController.delegate = self
    }
}

extension ParticipantListViewModel: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let participants = (controller.fetchedObjects as? [StoredParticipant]) ?? []
        _participants.accept(participants.compactMap(Participant.init))
    }
}

extension ParticipantListViewModel.SearchType {
    var title: String {
        switch self {
        case .number: return "Number"
        case .name: return "Username or DisplayName"
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .number: return .numberPad
        case .name: return .default
        }
    }
}
