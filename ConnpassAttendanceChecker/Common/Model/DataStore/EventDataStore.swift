//
//  EventDataStore.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/11.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation
import CoreData
import RxSwift
import RxCocoa
import Kanna

protocol EventDataStoreType: class {
    var htmlUpdated: Observable<Void> { get }
    var events: PropertyRelay<[Event]> { get }
    init(htmlDocument: Observable<HTMLDocument>,
         database: Database)
}

final class EventDataStore: NSObject, EventDataStoreType {
    let htmlUpdated: Observable<Void>

    let events: PropertyRelay<[Event]>
    private let _events: BehaviorRelay<[Event]>

    private let database: Database
    private let fetchedResultsController: NSFetchedResultsController<StoredEvent>
    private let disposeBag = DisposeBag()

    init(htmlDocument: Observable<HTMLDocument>,
         database: Database = .shared) {
        self.database = database
        let request: NSFetchRequest<StoredEvent> = StoredEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        self.fetchedResultsController = database.makeFetchedResultsController(fetchRequest: request)
        do {
            try fetchedResultsController.performFetch()
        } catch let e {
            print(e)
        }
        let results = fetchedResultsController.fetchedObjects ?? []
        self._events = BehaviorRelay(value: results.map(Event.init))
        self.events = PropertyRelay(_events)

        let _htmlUpdated = PublishRelay<Void>()
        self.htmlUpdated = _htmlUpdated.asObservable()

        htmlDocument
            .map { Event.list(from: $0) }
            .flatMap { events -> Single<Void> in
                database.perform(block: { context in
                    let request: NSFetchRequest<StoredEvent> = StoredEvent.fetchRequest()
                    let results = try context.fetch(request)

                    events.forEach { event in
                        guard results.lazy.filter({
                            $0.id == Int64(event.id) && $0.title == event.title
                        }).first == nil else {
                            return
                        }

                        let model = StoredEvent(context: context)
                        model.id = Int64(event.id)
                        model.title = event.title
                    }
                })
            }
            .bind(to: _htmlUpdated)
            .disposed(by: disposeBag)

        super.init()

        fetchedResultsController.delegate = self
    }
}

extension EventDataStore: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let events = (controller.fetchedObjects as? [StoredEvent]) ?? []
        _events.accept(events.compactMap(Event.init))
    }
}
