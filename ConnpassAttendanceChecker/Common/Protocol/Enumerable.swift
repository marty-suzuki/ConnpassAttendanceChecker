//
//  Enumerable.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/09.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation

protocol Enumerable {
    associatedtype Element = Self
}

extension Enumerable where Element: Hashable {
    private static var iterator: AnyIterator<Element> {
        var n = 0
        return AnyIterator {
            defer { n += 1 }

            let next = withUnsafePointer(to: &n) {
                UnsafeRawPointer($0).assumingMemoryBound(to: Element.self).pointee
            }
            return next.hashValue == n ? next : nil
        }
    }

    static var enumerate: EnumeratedSequence<AnySequence<Element>> {
        return AnySequence(self.iterator).enumerated()
    }

    static var elements: [Element] {
        return Array(self.iterator)
    }

    static var count: Int {
        return self.elements.count
    }
}
