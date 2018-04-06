//
//  Database.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import CoreData
import RxSwift

final class Database {
    private enum Const {
        static let name = "ConnpassAttendanceChecker"
        static let dataModelName = "ConnpassAttendanceChecker"
    }

    static let shared = Database(name: Const.name)

    private let name: String

    private var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    private lazy var backgroundContext: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = self.viewContext
        return context
    }()

    private lazy var applicationDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls.last!
    }()

    private lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: Const.dataModelName)
        if let store = container.persistentStoreDescriptions.first {
            store.url = self.applicationDocumentsDirectory.appendingPathComponent("\(self.name).splite")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    init(name: String) {
        self.name = name

        let nc = NotificationCenter.default
        [.UIApplicationWillTerminate,
         .UIApplicationDidEnterBackground]
            .forEach {
                nc.addObserver(self,
                               selector: #selector(Database.saveChanges(_:)),
                               name: $0,
                               object: nil)
        }
    }

    @objc
    private func saveChanges(_ notification: NSNotification) {
        saveContext()
    }

    private func saveContext() {
        func fatal(error: Swift.Error) {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }


        let save = { [weak backgroundContext, weak viewContext] in
            do {
                //if backgroundContext?.hasChanges == true {
                try backgroundContext?.save()
                //}
                viewContext?.performAndWait {
                    do {
                        //if viewContext?.hasChanges == true {
                        try viewContext?.save()
                        //}
                    } catch {
                        fatal(error: error)
                    }
                }
            } catch {
                fatal(error: error)
            }
        }

        if Thread.isMainThread {
            backgroundContext.perform { save() }
        } else {
            save()
        }
    }

    func makeFetchedResultsController<T>(fetchRequest: NSFetchRequest<T>) -> NSFetchedResultsController<T> {
        return NSFetchedResultsController(fetchRequest: fetchRequest,
                                          managedObjectContext: viewContext,
                                          sectionNameKeyPath: nil,
                                          cacheName: nil)
    }

    func perform(block: @escaping (NSManagedObjectContext) throws -> (), completion: @escaping (PerformResult) -> ()) {
        backgroundContext.perform { [weak self] in
            guard let me = self else { return }

            do {
                try block(me.backgroundContext)
                me.saveContext()
                completion(.success)
            } catch {
                completion(.error(error))
            }
        }
    }

    func perform(block: @escaping (NSManagedObjectContext) throws -> ()) -> Single<Void> {
        return Single.create { [weak self] event in

            self?.perform(block: { context in
                try block(context)
            }) { result in
                switch result {
                case .success:
                    event(.success(()))
                case .error(let e):
                    event(.error(e))
                }
            }

            return Disposables.create()
        }
    }
}

extension Database {
    enum PerformResult {
        case success
        case error(Swift.Error)
    }

    enum Error: Swift.Error {
        case objectNotFound
    }
}
