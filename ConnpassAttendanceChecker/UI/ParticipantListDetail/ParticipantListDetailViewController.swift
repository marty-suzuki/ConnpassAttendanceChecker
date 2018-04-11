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
    private let closeButton = UIBarButtonItem(title: "Close", style: .plain, target: nil, action: nil)


    private let participantListViewModel: ParticipantListViewModel
    private let disposeBag = DisposeBag()
    private lazy var videModel = ParticipantListDetailViewModel(childViewModel: self.participantListViewModel,
                                                                closeButtonTap: self.closeButton.rx.tap.asObservable())

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
        view.ex.addEdges(to: tableview)

        videModel.close
            .bind(to: Binder(self) { me, _ in
                me.dismiss(animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
    }
}
