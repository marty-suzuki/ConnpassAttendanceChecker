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

final class EventListViewController: UIViewController {
    private let tableview = UITableView(frame: .zero)
    private let registerButton = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)

    private lazy var viewModel = EventListViewModel(registerButtonTap: self.registerButton.rx.tap.asObservable(),
                                                    itemSelected: self.tableview.rx.itemSelected.asObservable())
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.ex.addEdges(to: tableview)
        navigationItem.rightBarButtonItem = registerButton
        navigationItem.title = "Connpass Event List"
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        tableview.dataSource = self
        tableview.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

        viewModel.showRegister
            .bind(to: Binder(self) { me, _ in
                let vc = EventRegisterViewController()
                let nc = UINavigationController(rootViewController: vc)
                me.present(nc, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)

        viewModel.reloadData
            .bind(to: Binder(tableview) { tableview, _ in
                tableview.reloadData()
            })
            .disposed(by: disposeBag)

        viewModel.selectedEvent
            .bind(to: Binder(self) { me, event in
                let vc = ParticipantListViewController(event: event)
                me.navigationController?.pushViewController(vc, animated: true)
            })
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = "\(viewModel.events.value[indexPath.row].title)"
        return cell
    }
}
