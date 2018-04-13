//
//  String.extension.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/13.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation

struct StringExtension {
    fileprivate let base: String
}

extension String {
    static var ex: StringExtension.Type {
        return StringExtension.self
    }
}

extension StringExtension {
    enum LocalizedKey: String {
        case all = "All"
        case cancel = "Cancel"
        case check = "Check"
        case close = "Close"
        case detail = "Detail"
        case displayName = "DisplayName"
        case doYouThisParticipant = "DoYouThisParticipant"
        case doYouWantLogout = "DoYouWantLogout"
        case doYouWantToRefresh = "DoYouWantToRefresh"
        case doYouWantRefreshEventList = "DoYouWantRefreshEventList"
        case export = "Export"
        case exportAsCSV = "ExportAsCSV"
        case howDoYouExportParticipantList = "HowDoYouExportParticipantList"
        case `in` = "In"
        case logout = "Logout"
        case managedEventList = "ManagedEventList"
        case no = "No"
        case number = "Number"
        case numberOfCheckIns = "NumberOfCheckIns"
        case numberOfParticipants = "NumberOfParticipants"
        case onlyCheckIn = "OnlyCheckIn"
        case or = "Or"
        case out = "Out"
        case refresh = "Refresh"
        case participantList = "ParticipantList"
        case participantListRefresh = "ParticipantListRefresh"
        case searchType = "SearchType"
        case userName = "UserName"
        case yes = "Yes"
    }

    static func localized(_ key: LocalizedKey) -> String {
        return NSLocalizedString(key.rawValue, comment: "")
    }
}
