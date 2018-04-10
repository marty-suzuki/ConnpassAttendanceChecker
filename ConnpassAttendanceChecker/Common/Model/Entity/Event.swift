//
//  Event.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation
import Kanna

struct Event {
    var id: Int
    var title: String
    var participants: [Participant]
}

extension Event: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.participants = []
    }

    static func list(from doc: HTMLDocument) -> [Event] {
        return doc.css("div[class='event_list']")
            .compactMap { eventList -> Event? in
                return eventList.css("table[class='EventList manage_list is_event']")
                    .compactMap { $0["data-obj"] }
                    .first
                    .flatMap {
                        guard let data = $0.data(using: .utf8) else {
                            return nil
                        }
                        do {
                            return try JSONDecoder().decode(Event.self, from: data)
                        } catch _ {
                            return nil
                        }
                    }
            }
    }

    init(_ event: StoredEvent) {
        self.id = Int(event.id)
        self.title = event.title ?? ""
        self.participants = (event.participants ?? [])
            .compactMap { ($0 as? StoredParticipant).map(Participant.init) }
    }
}
