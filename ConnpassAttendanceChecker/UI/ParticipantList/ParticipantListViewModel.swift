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

final class ParticipantListViewModel: NSObject {
    private enum Const {
        static let loginURLString = "https://connpass.com/login"
    }

    struct CheckedAlertElement {
        let index: Int
        let title: String
        let message: String
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

    private let _participants: BehaviorRelay<[Participant]>
    private let disposeBag = DisposeBag()
    private let fetchedResultsController: NSFetchedResultsController<StoredParticipant>

    init(event: Event,
         viewDidAppear: Observable<Bool>,
         navigationAction: Observable<WKNavigationAction>,
         htmlDocument: Observable<HTMLDocument>,
         loading: Observable<Bool>,
         numberText: Observable<String?>,
         cancelButtonTap: Observable<Void>,
         searchButtonTap: Observable<Void>,
         cameraButtonTap: Observable<Void>,
         checkedActionStyle: Observable<AlertActionStyle>,
         processPool: WKProcessPool = .init(),
         database: Database = .shared) {
        let request: NSFetchRequest<StoredParticipant> = StoredParticipant.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "number", ascending: false)]
        self.fetchedResultsController = database.makeFetchedResultsController(fetchRequest: request)
        try? fetchedResultsController.performFetch()
        let results = fetchedResultsController.fetchedObjects ?? []
        self._participants = BehaviorRelay(value: results.map(Participant.init))
        self.participants = PropertyRelay(_participants)

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

        self.reloadData = _participants
            .filter { !$0.isEmpty }
            .map { _ in }

        let _closeKeyboard = PublishRelay<Void>()
        self.closeKeyboard = _closeKeyboard.asObservable()

        let participantIndex = searchButtonTap
            .withLatestFrom(numberText)
            .unwrap()
            .flatMap { Int($0).map(Observable.just) ?? .empty() }
            .withLatestFrom(_participants) { ($0, $1) }
            .map { number, participants -> Int? in
                participants.index { $0.number == number }
            }
            .share()

        participantIndex
            .unwrap()
            .withLatestFrom(_participants) { ($0, $1) }
            .map { index, participants in
                let participant = participants[index]
                let strings = [
                    "Number: \(participant.number)",
                    "DisplayName: \(participant.displayName)",
                    "UserName: \(participant.userName)"
                ]
                let message = String(strings.joined(separator: "\n"))
                return CheckedAlertElement(index: index,
                                           title: "Do you check this participant?",
                                           message: message)
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
