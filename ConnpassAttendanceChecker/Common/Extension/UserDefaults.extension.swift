//
//  UserDefaults.extension.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/10.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation

struct UserDefaultsExtension {
    fileprivate let base: UserDefaults
}

extension UserDefaults {
    var ex: UserDefaultsExtension {
        return UserDefaultsExtension(base: self)
    }
}

extension UserDefaultsExtension {
    private enum Const {
        static let isLoggedIn = "isLoggedIn"
    }

    var isLoggedIn: Bool {
        set {
            base.set(newValue, forKey: Const.isLoggedIn)
        }
        get {
            return base.bool(forKey: Const.isLoggedIn)
        }
    }
}
