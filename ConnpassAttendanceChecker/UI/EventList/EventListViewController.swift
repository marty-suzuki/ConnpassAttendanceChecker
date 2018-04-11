//
//  EventListViewController.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import WebKit

final class EventListViewController: UIViewController {
    private let tableview = UITableView(frame: .zero)
    private let refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: nil, action: nil)
    private let logoutButton = UIBarButtonItem(title: "Logout", style: .plain, target: nil, action: nil)
    private let loadingView = LoadingView(frame: .zero)

    private lazy var viewModel = EventListViewModel(processPool: self.processPool,
                                                    viewDidAppear: self.ex.viewDidAppear,
                                                    refreshButtonTap: self.refreshButton.rx.tap.asObservable(),
                                                    logoutButtonTap: self.logoutButton.rx.tap.asObservable(),
                                                    itemSelected: self.tableview.rx.itemSelected.asObservable(),
                                                    alertHandler: self._alertHandler.asObservable(),
                                                    loggedOut: self.loggedOut,
                                                    webhookType: WebhookView.self,
                                                    dataStoreType: EventDataStore.self)
    private let disposeBag = DisposeBag()
    private let _alertHandler = PublishRelay<(AlertActionStyle, EventListViewModel.ActionType)>()
    private let cellIdentifier = "Cell"

    private let processPool: WKProcessPool
    private let loggedOut: AnyObserver<Void>

    init(processPool: WKProcessPool,
         loggedOut: AnyObserver<Void>) {
        self.processPool = processPool
        self.loggedOut = loggedOut
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.ex.addEdges(to: tableview)
        navigationItem.rightBarButtonItem = refreshButton
        navigationItem.leftBarButtonItem = logoutButton
        navigationItem.title = "Connpass Event List"
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        tableview.dataSource = self
        tableview.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)

        loadingView.isHidden = true
        view.ex.addEdges(to: loadingView)

        viewModel.reloadData
            .bind(to: Binder(tableview) { tableview, _ in
                tableview.reloadData()
            })
            .disposed(by: disposeBag)

        viewModel.selectedEvent
            .bind(to: Binder(self) { me, event in
                let vc = ParticipantListViewController(event: event,
                                                       processPool: me.processPool,
                                                       loggedOut: me.loggedOut)
                me.navigationController?.pushViewController(vc, animated: true)
            })
            .disposed(by: disposeBag)

        viewModel.hideLoading
            .bind(to: loadingView.rx.isHidden)
            .disposed(by: disposeBag)

        viewModel.enableRefresh
            .bind(to: refreshButton.rx.isEnabled)
            .disposed(by: disposeBag)

        viewModel.showAlert
            .flatMap { [weak self] arg in
                (self.map {
                    UIAlertController.ex.showAlert(element: arg.0, to: $0)
                } ?? .empty())
                .map { ($0, arg.1) }
            }
            .bind(to: _alertHandler)
            .disposed(by: disposeBag)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let indexPath = tableview.indexPathForSelectedRow {
            tableview.deselectRow(at: indexPath, animated: true)
        }
    }
}

extension EventListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.events.value.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        cell.textLabel?.text = "\(viewModel.events.value[indexPath.row].title)"
        return cell
    }
}
