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

final class EventListViewModel: NSObject {
    let showRegister: Observable<Void>
    let events: PropertyRelay<[Event]>
    let reloadData: Observable<Void>
    let selectedEvent: Observable<Event>

    private let _events: BehaviorRelay<[Event]>
    private let fetchedResultsController: NSFetchedResultsController<StoredEvent>

    init(registerButtonTap: Observable<Void>,
         itemSelected: Observable<IndexPath>,
         database: Database = .shared) {
        let request: NSFetchRequest<StoredEvent> = StoredEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        self.fetchedResultsController = database.makeFetchedResultsController(fetchRequest: request)
        try? fetchedResultsController.performFetch()
        let results = fetchedResultsController.fetchedObjects ?? []
        self._events = BehaviorRelay(value: results.compactMap(Event.init))
        self.events = PropertyRelay(_events)

        self.showRegister = registerButtonTap
        self.reloadData = events.skip(1).asObservable().map { _ in }
        self.selectedEvent = itemSelected
            .withLatestFrom(_events) { $1[$0.row] }

        super.init()

        fetchedResultsController.delegate = self

    }
}

extension EventListViewModel: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        let events = (controller.fetchedObjects as? [StoredEvent]) ?? []
        _events.accept(events.compactMap(Event.init))
    }
}
