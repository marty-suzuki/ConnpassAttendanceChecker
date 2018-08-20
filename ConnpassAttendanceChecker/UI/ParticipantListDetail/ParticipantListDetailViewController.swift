//
//  ParticipantListDetailViewController.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/12.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

final class ParticipantListDetailViewController: UIViewController {
    private let tableview = UITableView(frame: .zero)
    private let loadingView = LoadingView(frame: .zero)
    private let closeButton = UIBarButtonItem(title: String.ex.localized(.close), style: .plain, target: nil, action: nil)

    private let cellIdentifier = "Cell"

    private let participantListViewModel: ParticipantListViewModel
    private let _alertHandler = PublishRelay<(AlertActionStyle, ParticipantListDetailViewModel.Row)>()
    private let disposeBag = DisposeBag()
    private lazy var viewModel = ParticipantListDetailViewModel(childViewModel: self.participantListViewModel,
                                                                closeButtonTap: self.closeButton.rx.tap.asObservable(),
                                                                itemSelected: self.tableview.rx.itemSelected.asObservable(),
                                                                alertHandler: self._alertHandler.asObservable())

    init(viewModel: ParticipantListViewModel) {
        self.participantListViewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = closeButton

        if OS.current == .ios10 {
            tableview.rowHeight = UITableViewAutomaticDimension
            tableview.estimatedRowHeight = 44
        }
        tableview.dataSource = self
        tableview.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        view.ex.addEdges(to: tableview)

        loadingView.isHidden = true
        view.ex.addEdges(to: loadingView)

        viewModel.rows.skip(1)
            .bind(to: Binder(tableview) { tableview, _ in
                tableview.reloadData()
            })
            .disposed(by: disposeBag)

        viewModel.close
            .bind(to: Binder(self) { me, _ in
                me.dismiss(animated: true, completion: nil)
            })
            .disposed(by: disposeBag)

        viewModel.showAlert
            .observeOn(ConcurrentMainScheduler.instance)
            .flatMap { [weak self] element, row in
                (self.map {
                    UIAlertController.ex.showAlert(element: element, to: $0)
                } ?? .empty())
                .map { ($0, row) }
            }
            .bind(to: _alertHandler)
            .disposed(by: disposeBag)

        viewModel.deselectRow
            .bind(to: Binder(tableview) {
                $0.deselectRow(at: $1, animated: true)
            })
            .disposed(by: disposeBag)

        viewModel.csvURL
            .bind(to: Binder(self) { me, url in
                let avc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                me.present(avc, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)

        viewModel.hideLoading
            .bind(to: loadingView.rx.isHidden)
            .disposed(by: disposeBag)
    }
}

extension ParticipantListDetailViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.rows.value.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        let row = viewModel.rows.value[indexPath.row]
        let isSelectable = row.isSelectable

        cell.selectionStyle = isSelectable ? .blue : .none
        cell.textLabel?.textAlignment = isSelectable ? .center : .left
        cell.textLabel?.textColor = isSelectable ? UIColor.ex.blue : .black
        cell.textLabel?.font = {
            let pointSize = cell.textLabel?.font.pointSize ?? UIFont.systemFontSize
            let weight: UIFont.Weight = isSelectable ? .bold : .regular
            return .systemFont(ofSize: pointSize, weight: weight)
        }()

        let text: String
        switch row {
        case .title:
            text = viewModel.title
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 32)
        case .participantCount:
            text = "\(String.ex.localized(.numberOfParticipants)): \(viewModel.numberOfParticipants.value)"
        case .checkInCount:
            text = "\(String.ex.localized(.numberOfCheckIns)): \(viewModel.numberOfCheckIns.value)"
        case let .categorizedCounts(counts):
            text = "\(counts.ptype): \(counts.checkInCount) / \(counts.participantCount)"
        case .refresh:
            text = String.ex.localized(.refresh)
            cell.textLabel?.textAlignment = .center
        case .export:
            text = String.ex.localized(.export)
            cell.textLabel?.textAlignment = .center
        }

        cell.textLabel?.text = text
        cell.textLabel?.numberOfLines = 0

        return cell
    }
}
