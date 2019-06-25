//
//  UIView.extension.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit

struct UIViewExtension {
    fileprivate let base: UIView
}

extension UIView {
    var ex: UIViewExtension {
        return UIViewExtension(base: self)
    }
}

extension UIViewExtension {
    func addEdges(_ edges: [NSLayoutConstraint.Attribute] = [.top, .left, .right, .bottom], to view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        base.addSubview(view)
        let constrains = edges.map {
            NSLayoutConstraint(item: base,
                               attribute: $0,
                               relatedBy: .equal,
                               toItem: view,
                               attribute: $0,
                               multiplier: 1,
                               constant: 0)
        }
        NSLayoutConstraint.activate(constrains)
    }
}
