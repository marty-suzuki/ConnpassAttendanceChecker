//
//  OS.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/13.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation

enum OS {
    case ios10
    case ios11

    static var current: OS {
        if #available(iOS 11, *) {
            return .ios11
        } else {
            return .ios10
        }
    }
}
