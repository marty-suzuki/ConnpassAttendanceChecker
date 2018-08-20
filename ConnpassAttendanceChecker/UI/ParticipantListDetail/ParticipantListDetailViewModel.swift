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
        case categorizedCounts(CategorizedCounts)
        case refresh
        case export
    }

    enum CsvStyle {
        case all
        case onlyCheckIn
    }

    struct CategorizedCounts {
        let ptype: String
        fileprivate(set) var participantCount: Int
        fileprivate(set) var checkInCount: Int
    }

    let title: String

    let close: Observable<Void>
    let showAlert: Observable<(AlertElement, Row)>
    let csvURL: Observable<URL>
    let hideLoading: Observable<Bool>

    let deselectRow: Observable<IndexPath>

    let numberOfCheckIns: PropertyRelay<Int>
    private let _numberOfCheckIns = BehaviorRelay<Int>(value: 0)

    let numberOfParticipants: PropertyRelay<Int>
    private let _numberOfParticipants = BehaviorRelay<Int>(value: 0)

    let rows: PropertyRelay<[Row]>
    private let _rows = BehaviorRelay<[Row]>(value: [])

    private let disposeBag = DisposeBag()
    private let fileManager: FileManagerType

    init(childViewModel: ParticipantListViewModel,
         closeButtonTap: Observable<Void>,
         itemSelected: Observable<IndexPath>,
         alertHandler: Observable<(AlertActionStyle, Row)>,
         fileManager: FileManagerType = FileManager.default) {
        self.fileManager = fileManager
        let _hideLoading = PublishRelay<Bool>()
        self.hideLoading = _hideLoading.asObservable()

        self.title = childViewModel.event.title

        let selectedRowAndIndexPath = itemSelected
            .withLatestFrom(_rows) { ($1[$0.row], $0) }
            .share()

        let refreshAlert = selectedRowAndIndexPath
            .filter { $0.0.isRefresh }
            .map { _ -> (AlertElement, Row) in
                return (AlertElement(title: String.ex.localized(.participantListRefresh),
                                     message: String.ex.localized(.doYouWantToRefresh),
                                     actions: [.default(String.ex.localized(.yes)),
                                               .cancel(String.ex.localized(.no))]),
                        .refresh)
            }
            .share()

        let csvFilterAlert = selectedRowAndIndexPath
            .filter { $0.0.isExport }
            .map { _ -> (AlertElement, Row) in
                return (AlertElement(title: String.ex.localized(.exportAsCSV),
                                     message: String.ex.localized(.howDoYouExportParticipantList),
                                     actions: [.default(CsvStyle.all.title),
                                               .default(CsvStyle.onlyCheckIn.title),
                                               .cancel(String.ex.localized(.cancel))]),
                        .export)
            }
            .share()

        self.showAlert = Observable.merge(refreshAlert, csvFilterAlert)

        self.close = closeButtonTap

        self.deselectRow = selectedRowAndIndexPath
            .filter { $0.0.isSelectable }
            .map { $0.1 }

        self.numberOfCheckIns = PropertyRelay(_numberOfCheckIns)
        self.numberOfParticipants = PropertyRelay(_numberOfParticipants)
        self.rows = PropertyRelay(_rows)

        let _categorizedCounts = PublishRelay<[CategorizedCounts]>()
        _categorizedCounts
            .map { counts -> [Row] in
                [.title, .participantCount, .checkInCount] +
                counts.map(Row.categorizedCounts) +
                [.refresh, .export]
            }
            .bind(to: _rows)
            .disposed(by: disposeBag)

        let export = alertHandler
            .filter { $0.isDefault && $1.isExport  }
            .flatMap { values -> Observable<CsvStyle> in
                values.0.title
                    .flatMap(CsvStyle.init)
                    .map(Observable.just) ?? .empty()
            }
            .share()

        let event = childViewModel.event
        let csvURL = export
            .withLatestFrom(childViewModel.participants) { ($0, $1) }
            .observeOn(ConcurrentDispatchQueueScheduler(qos: .default))
            .map { [event, weak fileManager] style, participants -> URL? in
                guard let fileManager = fileManager else {
                    return nil
                }

                let strings: [String]
                switch style {
                case .all:
                    strings = participants
                        .map { $0.toCsvString() }
                case .onlyCheckIn:
                    strings = participants
                        .compactMap { $0.isChecked ? $0.toCsvString() : nil }
                }
                let csvString = Participant.firstLine() + strings.joined()

                guard let docsPath = NSSearchPathForDirectoriesInDomains(.documentationDirectory,
                                                                         .userDomainMask,
                                                                         true).first
                else {
                    return nil
                }
                let directoryPath = docsPath.appending("/csv")

                do {
                    try fileManager.createDirectory(atPath: directoryPath,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
                } catch _ {
                    return nil
                }

                let filePath = directoryPath.appending("/event\(event.id)_participants.csv")
                let fileURL = URL(fileURLWithPath: filePath)

                do {
                    try fileManager.write(csvString, to: fileURL, atomically: true, encoding: .utf8)
                    return fileURL
                } catch _ {
                    return nil
                }
            }
            .share()

        let refresh = alertHandler
            .filter { $0.isDefault && $1.isRefresh }
            .share()

        Observable.merge(childViewModel.hideLoading,
                         refresh.map { _ in false },
                         export.map { _ in false },
                         csvURL.map { _ in true })
            .bind(to: _hideLoading)
            .disposed(by: disposeBag)

        self.csvURL = csvURL.unwrap()
            .debug()

        childViewModel.participants
            .map { $0.lazy.filter { $0.isChecked }.count }
            .bind(to: _numberOfCheckIns)
            .disposed(by: disposeBag)

        childViewModel.participants
            .map { $0.count }
            .bind(to: _numberOfParticipants)
            .disposed(by: disposeBag)

        childViewModel.participants
            .map { participants -> [CategorizedCounts] in
                participants.reduce([CategorizedCounts]()) { countList, participant in
                    var _countList = countList
                    var _counts: CategorizedCounts
                    let index: Int

                    if let _index = countList.index(where: { $0.ptype == participant.ptype }) {
                        _counts = _countList[_index]
                        index = _index
                    } else {
                        _counts = CategorizedCounts(ptype: participant.ptype,
                                                       participantCount: 0,
                                                       checkInCount: 0)
                        _countList.append(_counts)
                        index = _countList.count - 1
                    }

                    _counts.participantCount += 1
                    if participant.isChecked {
                        _counts.checkInCount += 1
                    }
                    _countList[index] = _counts

                    return _countList
                }
            }
            .bind(to: _categorizedCounts)
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
             .participantCount,
             .categorizedCounts:
            return false
        case .export,
             .refresh:
            return true
        }
    }

    var isRefresh: Bool {
        if case .refresh = self {
            return true
        }
        return false
    }

    var isExport: Bool {
        if case .export = self {
            return true
        }
        return false
    }
}

extension ParticipantListDetailViewModel.CsvStyle {
    var title: String {
        let ex = String.ex
        switch  self {
        case .all:
            return ex.localized(.all)
        case .onlyCheckIn:
            return ex.localized(.onlyCheckIn)
        }
    }

    fileprivate init?(rawValue: String) {
        let ex = String.ex
        switch rawValue {
        case ex.localized(.all):
            self = .all
        case ex.localized(.onlyCheckIn):
            self = .onlyCheckIn
        default:
            return nil
        }
    }
}
