//
//  Participant.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation
import Kanna

struct Participant {
    var ptype: String
    var eventID: Int
    var number: Int
    var displayName: String
    var userName: String
    var thumbnail: String
    var isChecked: Bool
}

extension Participant {
    static func list(from doc: HTMLDocument, eventID: Int) -> [Participant] {
        return doc.css("tr[class='ParticipantView']")
            .compactMap { participantView -> Participant? in
                guard
                    let id = participantView.at_css("td[class='id']"),
                    let user = participantView.at_css("td[class='user']"),
                    let number = (id.at_css("span[class='number']")?.text).flatMap(Int.init),
                    let displayName = user.at_css("span[class='display_name']")?.text,
                    let _userName = user.at_css("span[class='user_name']")?.text,
                    let thumbnail = user.at_css("a[class='image_link']")?.css("img").lazy.compactMap({ $0["src"] }).first
                else {
                    return nil
                }

                let userName: String
                if _userName.hasPrefix("(") && _userName.hasSuffix(")") {
                    let start = _userName.index(after: _userName.startIndex)
                    let end = _userName.index(before: _userName.endIndex)
                    userName = String(_userName[start..<end])
                } else {
                    userName = _userName
                }
                return Participant(ptype: id.at_css("span[class='label_ptype_name']")?.text ?? "補欠またはキャンセル",
                                   eventID: eventID,
                                   number: number,
                                   displayName: displayName,
                                   userName: userName,
                                   thumbnail: thumbnail,
                                   isChecked: false)
            }
    }

    init?(_ participant: StoredParticipant) {
        guard let eventID = participant.event?.id else {
            return nil
        }

        self.ptype = participant.ptype ?? ""
        self.eventID = Int(eventID)
        self.number = Int(participant.number)
        self.displayName = participant.displayName ?? ""
        self.userName = participant.userName ?? ""
        self.thumbnail = participant.thumbnail ?? ""
        self.isChecked = participant.isChecked
    }

    static func firstLine() -> String {
        return "number,pType,username,displayname,isChecked\n"
    }

    func toCsvString() -> String {
        return "\(number),\(ptype),\(userName),\"\(displayName)\",\(isChecked)\n"
    }
}
