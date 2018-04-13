//
//  FileManager.extension.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/14.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation

protocol FileManagerType: class {
    func createDirectory(atPath path: String,
                         withIntermediateDirectories createIntermediates: Bool,
                         attributes: [FileAttributeKey : Any]?) throws
    func write(_ string: String, to url: URL, atomically: Bool, encoding: String.Encoding) throws
}

extension FileManagerType {
    func write(_ string: String, to url: URL, atomically: Bool, encoding: String.Encoding) throws {
        try string.write(to: url, atomically: atomically, encoding: encoding)
    }
}

extension FileManager: FileManagerType {}
