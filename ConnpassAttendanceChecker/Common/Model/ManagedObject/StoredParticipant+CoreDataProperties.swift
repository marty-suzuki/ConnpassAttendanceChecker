//
//  StoredParticipant+CoreDataProperties.swift
//  
//
//  Created by 鈴木大貴 on 2018/04/17.
//
//

import Foundation
import CoreData


extension StoredParticipant {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StoredParticipant> {
        return NSFetchRequest<StoredParticipant>(entityName: "StoredParticipant")
    }

    @NSManaged public var displayName: String?
    @NSManaged public var isChecked: Bool
    @NSManaged public var number: Int64
    @NSManaged public var ptype: String?
    @NSManaged public var userName: String?
    @NSManaged public var updatedAt: Double
    @NSManaged public var event: StoredEvent?

}
