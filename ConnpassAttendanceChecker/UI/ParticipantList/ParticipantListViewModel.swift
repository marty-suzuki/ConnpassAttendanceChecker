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

    let reloadData: Observable<Void>

    let processPool: PropertyRelay<WKProcessPool>
    private let _processPool: BehaviorRelay<WKProcessPool>

    let participantsURL: Observable<URL>
    private let _participantsURL = BehaviorRelay<URL?>(value: nil)

    let navigationActionPolicy: Observable<WKNavigationActionPolicy>
    private let _navigationActionPolicy = PublishRelay<WKNavigationActionPolicy>()

    let participants: PropertyRelay<[Participant]>
    private let _participants: BehaviorRelay<[Participant]>

    let showLogin: Observable<WKProcessPool>
    private let _showLogin = PublishRelay<WKProcessPool>()

    let getHTMLDocument: Observable<Void>
    private let _getHTMLDocument = PublishRelay<Void>()

    private let disposeBag = DisposeBag()
    private let fetchedResultsController: NSFetchedResultsController<StoredParticipant>

    init(event: Event,
         viewDidAppear: Observable<Bool>,
         navigationAction: Observable<WKNavigationAction>,
         htmlDocument: Observable<HTMLDocument>,
         loading: Observable<Bool>,
         processPool: WKProcessPool = .init(),
         database: Database = .shared) {
        let request: NSFetchRequest<StoredParticipant> = StoredParticipant.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "number", ascending: false)]
        self.fetchedResultsController = database.makeFetchedResultsController(fetchRequest: request)
        try? fetchedResultsController.performFetch()
        let results = fetchedResultsController.fetchedObjects ?? []
        self._participants = BehaviorRelay(value: results.map(Participant.init))
        self.participants = PropertyRelay(_participants)

        self._processPool = BehaviorRelay(value: processPool)
        self.processPool = PropertyRelay(_processPool)
        self.participantsURL = _participantsURL.unwrap()
        self.navigationActionPolicy = _navigationActionPolicy.asObservable()
        self.showLogin = _showLogin.asObservable()
        self.getHTMLDocument = _getHTMLDocument.asObservable()
        self.reloadData = _participants
            .filter { !$0.isEmpty }
            .map { _ in }

        htmlDocument
            .map { [event] in Participant.list(from: $0, eventID: event.id) }
            .flatMap { participants in
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

        let navigationActionURL = navigationAction
            .map { $0.request.url }
            .share()

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
                .withLatestFrom(_processPool)
                .bind(to: _showLogin)
                .disposed(by: disposeBag)
        }

        let containsParticipantsURLString = navigationActionURL
            .unwrap()
            .withLatestFrom(_participantsURL.unwrap()) { ($0, $1) }
            .filter { $0.absoluteString.contains($1.absoluteString) }
            .map { _ in }

        Observable.combineLatest(loading, containsParticipantsURLString)
            .filter { !$0.0 }
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
