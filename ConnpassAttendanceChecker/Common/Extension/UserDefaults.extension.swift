//
//  UserDefaults.extension.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/10.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation

protocol UserDefaultsType: class {
    func set(_ value: Bool, forKey key: String)
    func bool(forKey key: String) -> Bool
}

struct UserDefaultsExtension {
    fileprivate let base: UserDefaultsType
}

extension UserDefaultsType {
    var ex: UserDefaultsExtension {
        return UserDefaultsExtension(base: self)
    }
}

extension UserDefaults: UserDefaultsType {}

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
