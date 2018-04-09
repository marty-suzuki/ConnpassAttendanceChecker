//
//  ParticipantDataStore.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/09.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation
import CoreData
import RxSwift
import RxCocoa
import Kanna

final class ParticipantDataStore: NSObject {
    let updatedIndex: Observable<Int>
    let htmlUpdated: Observable<Void>
    let filteredParticipants: Observable<[Participant]>
    let indexAndParticipant: Observable<(Int, Participant)>

    let participants: PropertyRelay<[Participant]>
    private let _participants: BehaviorRelay<[Participant]>

    private let database: Database
    private let fetchedResultsController: NSFetchedResultsController<StoredParticipant>
    private let disposeBag = DisposeBag()

    init(event: Event,
         htmlDocument: Observable<HTMLDocument>,
         updateChehckedWithIndex: Observable<(Bool, Int)>,
         filterWithNunmber: Observable<Int>,
         filterWithName: Observable<String>,
         indexOfParticipant: Observable<Participant>,
         database: Database = .shared) {
        self.database = database
        let request: NSFetchRequest<StoredParticipant> = StoredParticipant.fetchRequest()
        request.predicate = NSPredicate(format: "eventID = %lld", event.id)
        request.sortDescriptors = [NSSortDescriptor(key: "number", ascending: false)]
        self.fetchedResultsController = database.makeFetchedResultsController(fetchRequest: request)
        do {
            try fetchedResultsController.performFetch()
        } catch let e {
            print(e)
        }
        let results = fetchedResultsController.fetchedObjects ?? []
        self._participants = BehaviorRelay(value: results.map(Participant.init))
        self.participants = PropertyRelay(_participants)

        self.indexAndParticipant = indexOfParticipant
            .withLatestFrom(_participants) { ($0, $1) }
            .flatMap { participant, participants -> Observable<(Int, Participant)> in
                guard let index = participants.index(where: {
                    $0.number == participant.number &&
                    $0.userName == participant.userName &&
                    $0.displayName == participant.displayName
                }) else {
                    return .empty()
                }
                return .just((index, participant))
            }

        let numberFilteredParticipants = filterWithNunmber
            .withLatestFrom(_participants) { ($0, $1) }
            .map { number, participants in
                participants.filter { "\($0.number)".contains("\(number)") }
            }

        let nameFilteredParticipants = filterWithName
            .withLatestFrom(_participants)  { ($0, $1) }
            .map { name, participants in
                participants.filter {
                    let name = name.lowercased()
                    return $0.userName.lowercased().contains(name) ||
                        $0.displayName.lowercased().contains(name)
                }
            }

        self.filteredParticipants = Observable.merge(numberFilteredParticipants,
                                                     nameFilteredParticipants)

        let _updatedIndex = PublishRelay<Int>()
        self.updatedIndex = _updatedIndex.asObservable()

        let _htmlUpdated = PublishRelay<Void>()
        self.htmlUpdated = _htmlUpdated.asObservable()

        updateChehckedWithIndex
            .withLatestFrom(_participants) { ($0.0, $0.1, $1) }
            .flatMap { isChecked, index, participants -> Observable<Int> in
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

                    object.isChecked = isChecked
                })
                .asObservable()
                .catchError { _ in .empty() }
                .map { index }
            }
            .bind(to: _updatedIndex)
            .disposed(by: disposeBag)

        htmlDocument
            .map { [event] in Participant.list(from: $0, eventID: event.id) }
            .flatMap { [event] participants -> Single<Void> in
                database.perform(block: { [event] context in
                    let request: NSFetchRequest<StoredParticipant> = StoredParticipant.fetchRequest()
                    request.predicate = NSPredicate(format: "eventID = %lld", event.id)
                    let results = try context.fetch(request)

                    participants.forEach { participant in
                        guard results.lazy.filter({
                            $0.number == participant.number &&
                            $0.userName == participant.userName &&
                            $0.displayName == participant.displayName
                        }).first == nil else {
                            return
                        }

                        let model = StoredParticipant(context: context)
                        model.number = Int64(participant.number)
                        model.ptype = participant.ptype
                        model.displayName = participant.displayName
                        model.userName = participant.userName
                        model.eventID = Int64(participant.eventID)
                    }
                })
            }
            .bind(to: _htmlUpdated)
            .disposed(by: disposeBag)

        super.init()

        fetchedResultsController.delegate = self
    }
}

extension ParticipantDataStore: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let participants = (controller.fetchedObjects as? [StoredParticipant]) ?? []
        _participants.accept(participants.compactMap(Participant.init))
    }
}
