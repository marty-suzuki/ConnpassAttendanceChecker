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
import FirebaseDatabase

protocol ParticipantDataStoreType: class {
    var updatedIndex: Observable<Int> { get }
    var htmlUpdated: Observable<Void> { get }
    var filteredParticipants: Observable<[Participant]> { get }
    var indexAndParticipant: Observable<(Int, Participant)> { get }
    var participants: PropertyRelay<[Participant]> { get }
    init(event: Event,
         htmlDocument: Observable<HTMLDocument>,
         updateChehckedWithIndex: Observable<(Bool, Int)>,
         filterWithNunmber: Observable<Int>,
         filterWithName: Observable<String>,
         indexOfParticipant: Observable<Participant>,
         useFirebaseDatabase: Bool,
         database: DatabaseType)
}

final class ParticipantDataStore: NSObject, ParticipantDataStoreType {
    let updatedIndex: Observable<Int>
    let htmlUpdated: Observable<Void>
    let filteredParticipants: Observable<[Participant]>
    let indexAndParticipant: Observable<(Int, Participant)>

    let participants: PropertyRelay<[Participant]>
    private let _participants: BehaviorRelay<[Participant]>

    private let database: DatabaseType
    private let fetchedResultsController: NSFetchedResultsController<StoredParticipant>
    private let disposeBag = DisposeBag()
    private let reference: DatabaseReference?

    init(event: Event,
         htmlDocument: Observable<HTMLDocument>,
         updateChehckedWithIndex: Observable<(Bool, Int)>,
         filterWithNunmber: Observable<Int>,
         filterWithName: Observable<String>,
         indexOfParticipant: Observable<Participant>,
         useFirebaseDatabase: Bool,
         database: DatabaseType = Database.shared) {
        self.database = database
        self.reference = useFirebaseDatabase ? FirebaseDatabase.Database.database().reference() : nil
        
        let request: NSFetchRequest<StoredParticipant> = StoredParticipant.fetchRequest()
        request.predicate = NSPredicate(format: "event.id = %lld", event.id)
        request.sortDescriptors = [NSSortDescriptor(key: "number", ascending: true)]
        self.fetchedResultsController = database.makeFetchedResultsController(fetchRequest: request)

        do {
            try fetchedResultsController.performFetch()
        } catch let e {
            print(e)
        }
        let results = fetchedResultsController.fetchedObjects ?? []
        let participants = results.compactMap(Participant.init)
        self._participants = BehaviorRelay(value: participants)
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

        let updateInfo = updateChehckedWithIndex
            .withLatestFrom(_participants) { ($0.0, $0.1, $1, Date().timeIntervalSince1970) }
            .share()

        updateInfo
            .flatMap { [weak database] isChecked, index, participants, updatedAt -> Observable<Int> in
                let participant = participants[index]
                return database?.perform(block: { context in
                    let request: NSFetchRequest<StoredParticipant> = StoredParticipant.fetchRequest()
                    request.fetchLimit = 1
                    request.predicate = NSPredicate(format: "number = %lld AND event.id = %lld",
                                                    participant.number,
                                                    participant.eventID)

                    guard let object = try context.fetch(request).first else {
                        throw Database.Error.objectNotFound
                    }

                    object.isChecked = isChecked
                    object.updatedAt = updatedAt
                })
                .asObservable()
                .catchError { _ in .empty() }
                .map { index } ?? .empty()
            }
            .bind(to: _updatedIndex)
            .disposed(by: disposeBag)

        htmlDocument
            .map { [event] in Participant.list(from: $0, eventID: event.id) }
            .flatMap { [event, weak database] participants -> Observable<Void> in
                database?.perform(block: { [event] context in
                    let eventRequest: NSFetchRequest<StoredEvent> = StoredEvent.fetchRequest()
                    eventRequest.predicate = NSPredicate(format: "id = %lld", event.id)
                    eventRequest.fetchLimit = 1
                    guard let fetchedEvent = try context.fetch(eventRequest).first else {
                        return
                    }

                    let participantRequest: NSFetchRequest<StoredParticipant> = StoredParticipant.fetchRequest()
                    participantRequest.predicate = NSPredicate(format: "event.id = %lld", event.id)
                    let fetchedParticipants = try context.fetch(participantRequest)

                    participants.forEach { participant in
                        guard fetchedParticipants.lazy.filter({
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
                        model.updatedAt = Date().timeIntervalSince1970
                        model.event = fetchedEvent
                    }
                }).asObservable() ?? .empty()
            }
            .bind(to: _htmlUpdated)
            .disposed(by: disposeBag)

        super.init()

        fetchedResultsController.delegate = self

        if useFirebaseDatabase {
            updateInfo
                .subscribe(onNext: { [weak self] isChecked, index, participants, updatedAt in
                    guard let reference = self?.reference else { return }
                    let participant = participants[index]
                    reference
                        .child("\(Keys.participants)/\(participant.number)")
                        .setValue([Keys.isChecked: isChecked, Keys.updatedAt: updatedAt])
                })
                .disposed(by: disposeBag)

            reference?.rx.snapshot(for: .value)
                .flatMap { ($0.value as? [String: Any]).map(Observable.just) ?? .empty() }
                .map { SnapshotContents($0).contents }
                .flatMap { [event, weak database] contents -> Observable<[SnapshotContents.Content]> in
                    guard let database = database else {
                        return .empty()
                    }
                    var differences: [SnapshotContents.Content] = []
                    return database.perform(block: { [event] context in
                            let participantRequest: NSFetchRequest<StoredParticipant> = StoredParticipant.fetchRequest()
                            participantRequest.predicate = NSPredicate(format: "event.id = %lld", event.id)
                            let fetchedParticipants = try context.fetch(participantRequest)

                            contents.forEach { content in
                                guard let participant = fetchedParticipants.lazy.filter({
                                    $0.number == content.number
                                }).first else {
                                    return
                                }

                                guard participant.isChecked != content.isChecked else {
                                    return
                                }

                                if participant.updatedAt < content.updatedAt {
                                    participant.isChecked = content.isChecked
                                    participant.updatedAt = content.updatedAt
                                } else {
                                    let newContent = SnapshotContents.Content(number: content.number,
                                                                              isChecked: participant.isChecked,
                                                                              updatedAt: participant.updatedAt)
                                    differences.append(newContent)
                                }
                            }
                        })
                        .map { differences }
                        .asObservable()
                }
                .subscribe(onNext: { [weak self] differences in
                    guard !differences.isEmpty, let reference = self?.reference else { return }
                    differences.forEach { content in
                        reference
                            .child("\(Keys.participants)/\(content.number)")
                            .setValue([Keys.isChecked: content.isChecked,
                                       Keys.updatedAt: content.updatedAt])
                    }
                })
                .disposed(by: disposeBag)
        }
    }
}

extension ParticipantDataStore {
    fileprivate enum Keys {
        static let participants = "participants"
        static let isChecked = "isChecked"
        static let updatedAt = "updatedAt"
    }

    fileprivate struct SnapshotContents {
        struct Content {
            let number: Int
            let isChecked: Bool
            let updatedAt: TimeInterval
        }

        let contents: [Content]

        init(_ value: [String: Any]) {
            guard let contents = value[Keys.participants] as? [String: [String: Any]] else {
                self.contents = []
                return
            }

            self.contents = contents.keys.compactMap { key in
                guard let number = Int(key) else {
                    return nil
                }
                guard let isChecked = contents[key]?[Keys.isChecked] as? Bool else {
                    return nil
                }
                guard let updatedAt = contents[key]?[Keys.updatedAt] as? TimeInterval else {
                    return nil
                }
                return Content(number: number, isChecked: isChecked, updatedAt: updatedAt)
            }
        }
    }
}

extension ParticipantDataStore: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let participants = (controller.fetchedObjects as? [StoredParticipant]) ?? []
        _participants.accept(participants.compactMap(Participant.init))
    }
}
