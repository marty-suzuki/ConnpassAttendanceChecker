//
//  Event.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation

struct Event {
    var id: Int
    var title: String
    var participants: [Participant]
}

extension Event {
    init(_ event: StoredEvent) {
        self.id = Int(event.id)
        self.title = event.title ?? ""
        self.participants = (event.participants ?? [])
            .compactMap { ($0 as? StoredParticipant).map(Participant.init) }
    }
}
