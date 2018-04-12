//
//  ParticipantListDetailViewModel.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/12.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

final class ParticipantListDetailViewModel {
    enum Row: Enumerable {
        case title
        case participantCount
        case checkInCount
        case refresh
        case export
    }

    enum CsvStyle: String {
        case all = "All"
        case onlyCheckIn = "Only CheckIn"
    }

    let title: String

    let close: Observable<Void>
    let showAlert: Observable<(AlertElement, Row)>
    let csvURL: Observable<URL>
    let hideLoading: Observable<Bool>

    let rows = PropertyRelay<[Row]>(Row.elements)
    let deselectRow: Observable<IndexPath>

    let numberOfCheckIns: PropertyRelay<Int>
    private let _numberOfCheckIns = BehaviorRelay<Int>(value: 0)

    let numberOfParticipants: PropertyRelay<Int>
    private let _numberOfParticipants = BehaviorRelay<Int>(value: 0)

    private let disposeBag = DisposeBag()

    init(childViewModel: ParticipantListViewModel,
         closeButtonTap: Observable<Void>,
         itemSelected: Observable<IndexPath>,
         alertHandler: Observable<(AlertActionStyle, Row)>) {
        let _hideLoading = PublishRelay<Bool>()
        self.hideLoading = _hideLoading.asObservable()

        self.title = childViewModel.event.title

        let selectedRowAndIndexPath = itemSelected
            .withLatestFrom(rows) { ($1[$0.row], $0) }
            .share()

        let refreshAlert = selectedRowAndIndexPath
            .filter { $0.0 == .refresh }
            .map { _ -> (AlertElement, Row) in
                return (AlertElement(title: "Participant List Refresh",
                                     message: "Do you want to refresh?",
                                     actions: [.default("YES"), .cancel("NO")]),
                        .refresh)
            }
            .share()

        let csvFilterAlert = selectedRowAndIndexPath
            .filter { $0.0 == .export }
            .map { _ -> (AlertElement, Row) in
                return (AlertElement(title: "Export as CSV",
                                     message: "How do you export participant list?",
                                     actions: [.default(CsvStyle.all.rawValue),
                                               .default(CsvStyle.onlyCheckIn.rawValue),
                                               .cancel("Cancel")]),
                        .refresh)
            }
            .share()

        self.showAlert = Observable.merge(refreshAlert, csvFilterAlert)

        self.close = closeButtonTap

        self.deselectRow = selectedRowAndIndexPath
            .filter { $0.0.isSelectable }
            .map { $0.1 }

        self.numberOfCheckIns = PropertyRelay(_numberOfCheckIns)
        self.numberOfParticipants = PropertyRelay(_numberOfParticipants)

        let export = alertHandler
            .filter { $0.isDefault && $1 == .export  }
            .flatMap { values -> Observable<CsvStyle> in
                values.0.title
                    .flatMap(CsvStyle.init)
                    .map(Observable.just) ?? .empty()
            }
            .share()

        let refresh = alertHandler
            .filter { $0.isDefault && $1 == .refresh }
            .share()

        let csvURL = export
            .withLatestFrom(childViewModel.participants) { ($0, $1) }
            .observeOn(ConcurrentDispatchQueueScheduler(qos: .default))
            .map { style, participants -> URL? in
                let firstLine = "number,username,displayname,isChecked\n"
                let strings: [String]
                switch style {
                case .all:
                    strings = participants
                        .map { "\($0.number),\($0.userName),\($0.displayName),\($0.isChecked)\n" }
                case .onlyCheckIn:
                    strings = participants
                        .flatMap { $0.isChecked ? "\($0.number),\($0.userName),\($0.displayName),\($0.isChecked)\n" : nil }
                }
                let csvString = firstLine + strings.joined()

                guard let docsPath = NSSearchPathForDirectoriesInDomains(.documentationDirectory, .userDomainMask, true).first else {
                    return nil
                }
                let directoryPath = docsPath.appending("/csv")

                do {
                    try FileManager.default.createDirectory(atPath: directoryPath,
                                                            withIntermediateDirectories: true,
                                                            attributes: nil)
                } catch _ {
                    return nil
                }

                let filePath = directoryPath.appending("/participants.csv")
                let fileURL = URL(fileURLWithPath: filePath)

                do {
                    try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
                    return fileURL
                } catch _ {
                    return nil
                }
            }
            .share()

        Observable.merge(childViewModel.hideLoading,
                         refresh.map { _ in false },
                         export.map { _ in false },
                         csvURL.map { _ in true })
            .bind(to: _hideLoading)
            .disposed(by: disposeBag)

        self.csvURL = csvURL.unwrap()

        childViewModel.participants
            .map { $0.lazy.filter { $0.isChecked }.count }
            .bind(to: _numberOfCheckIns)
            .disposed(by: disposeBag)

        childViewModel.participants
            .map { $0.count }
            .bind(to: _numberOfParticipants)
            .disposed(by: disposeBag)

        refresh
            .map { _ in }
            .bind(to: childViewModel.refresh)
            .disposed(by: disposeBag)
    }
}

extension ParticipantListDetailViewModel.Row {
    var isSelectable: Bool {
        switch self {
        case .title,
             .checkInCount,
             .participantCount:
            return false
        case .export,
             .refresh:
            return true
        }
    }
}
