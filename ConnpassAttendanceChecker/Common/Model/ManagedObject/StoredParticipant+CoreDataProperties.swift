//
//  StoredParticipant+CoreDataProperties.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//
//

import Foundation
import CoreData


extension StoredParticipant {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StoredParticipant> {
        return NSFetchRequest<StoredParticipant>(entityName: "StoredParticipant")
    }

    @NSManaged public var displayName: String?
    @NSManaged public var eventID: Int64
    @NSManaged public var number: Int64
    @NSManaged public var ptype: String?
    @NSManaged public var userName: String?
    @NSManaged public var isChecked: Bool

}
