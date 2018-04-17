//
//  FirebaseManager.swift
//  ConnpassAttendanceChecker
//
//  Created by 鈴木大貴 on 2018/04/17.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import FirebaseCore

final class FirebaseManager {
    static let shared = FirebaseManager()

    let isEnabled: Bool

    init() {
        if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: filePath) {
            self.isEnabled = !plist.allValues.isEmpty
        } else {
            self.isEnabled = false
        }
    }

    func configureIfNeeded() {
        if isEnabled {
            FirebaseApp.configure()
        }
    }
}
