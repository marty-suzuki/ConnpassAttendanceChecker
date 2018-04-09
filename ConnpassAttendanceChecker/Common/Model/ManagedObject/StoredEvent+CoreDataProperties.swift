//
//  StoredEvent+CoreDataProperties.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//
//

import Foundation
import CoreData


extension StoredEvent {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StoredEvent> {
        return NSFetchRequest<StoredEvent>(entityName: "StoredEvent")
    }

    @NSManaged public var id: Int64
    @NSManaged public var title: String?
    @NSManaged public var participants: NSSet?

}

// MARK: Generated accessors for participants
extension StoredEvent {

    @objc(addParticipantsObject:)
    @NSManaged public func addToParticipants(_ value: StoredParticipant)

    @objc(removeParticipantsObject:)
    @NSManaged public func removeFromParticipants(_ value: StoredParticipant)

    @objc(addParticipants:)
    @NSManaged public func addToParticipants(_ values: NSSet)

    @objc(removeParticipants:)
    @NSManaged public func removeFromParticipants(_ values: NSSet)

}
