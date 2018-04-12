//
//  UIColor.extension.swift
//  ConnpassAttendanceChecker
//
//  Created by 鈴木大貴 on 2018/04/12.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit

struct UIColorExtension {
    fileprivate let base: UIColor
}

extension UIColor {
    static var ex: UIColorExtension.Type {
        return UIColorExtension.self
    }
}

extension UIColorExtension {
    static var blue: UIColor {
        return UIColor(red: 0, green: 0.478, blue: 1, alpha: 1)
    }
}
