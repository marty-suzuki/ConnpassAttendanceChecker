//
//  ParticipantListViewController.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit
import WebKit
import RxSwift
import RxCocoa
import Kanna

final class ParticipantListViewController: UIViewController {
    private let tableview = UITableView(frame: .zero)
    private let detailButton = UIBarButtonItem(title: String.ex.localized(.detail), style: .plain, target: nil, action: nil)
    private let selectorButton = UIBarButtonItem(title: nil, style: .plain, target: nil, action: nil)
    private let pickerView = UIPickerView(frame: .zero)
    private let loadingView = LoadingView(frame: .zero)
    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.showsCancelButton = true
        return searchBar
    }()
    private lazy var searchToolbar: UIToolbar = {
        let toolbar = UIToolbar(frame: .zero)
        toolbar.clipsToBounds = true
        if OS.current == .ios11 {
            self.searchBar.translatesAutoresizingMaskIntoConstraints = false
        }
        let textFeild = UIBarButtonItem(customView: self.searchBar)
        toolbar.setItems([textFeild], animated: false)
        return toolbar
    }()
    private lazy var searchTypeToolbar: UIToolbar = {
        let toolbar = UIToolbar(frame: .zero)
        toolbar.clipsToBounds = true
        let spacer1 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let spacer2 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.setItems([spacer1, self.selectorButton, spacer2], animated: false)
        return toolbar
    }()
    private lazy var pickerToolbar: UIToolbar = {
        let toolbar = UIToolbar(frame: .zero)
        if OS.current == .ios11 {
            self.pickerView.translatesAutoresizingMaskIntoConstraints = false
        }
        let pickerView = UIBarButtonItem(customView: self.pickerView)
        toolbar.setItems([pickerView], animated: false)
        return toolbar
    }()
    private lazy var pickerToolbarTopConstraint: NSLayoutConstraint = {
        searchTypeToolbar.bottomAnchor.constraint(equalTo: pickerToolbar.topAnchor)
    }()

    private let event: Event
    private let processPool: WKProcessPool
    private let loggedOut: AnyObserver<Void>
    private let pickerToolbarHeight: CGFloat = 100
    private let disposeBag = DisposeBag()

    private let _checkedActionStyle = PublishRelay<AlertActionStyle>()
    private lazy var viewModel = ParticipantListViewModel(event: self.event,
                                                          processPool: self.processPool,
                                                          viewWillAppear: self.ex.viewWillAppear,
                                                          searchText: self.searchBar.rx.text.asObservable(),
                                                          cancelButtonTap: self.searchBar.rx.cancelButtonClicked.asObservable(),
                                                          searchButtonTap: self.searchBar.rx.searchButtonClicked.asObservable(),
                                                          selectorButtonTap: self.selectorButton.rx.tap.asObservable(),
                                                          detailButtonTap: self.detailButton.rx.tap.asObservable(),
                                                          checkedActionStyle: self._checkedActionStyle.asObservable(),
                                                          pickerItemSelected: self.pickerView.rx.itemSelected.asObservable(),
                                                          tableViewItemSelected:  self.tableview.rx.itemSelected.asObservable(),
                                                          loggedOut: self.loggedOut,
                                                          webhookType: WebhookView.self,
                                                          dataStoreType: ParticipantDataStore.self)

    init(event: Event,
         processPool: WKProcessPool,
         loggedOut: AnyObserver<Void>) {
        self.event = event
        self.processPool = processPool
        self.loggedOut = loggedOut
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = String.ex.localized(.participantList)
        navigationItem.rightBarButtonItem = detailButton

        if OS.current == .ios10 {
            tableview.rowHeight = UITableViewAutomaticDimension
            tableview.estimatedRowHeight = 44
        }
        tableview.dataSource = self
        let nib = UINib(nibName: ParticipantCell.identifier, bundle: nil)
        tableview.register(nib, forCellReuseIdentifier: ParticipantCell.identifier)
        view.ex.addEdges(to: tableview)

        do {
            let toolbarHeight: CGFloat = 44
            let elements = [
                (ex.topAnchor, searchToolbar),
                (searchToolbar.bottomAnchor, searchTypeToolbar)
            ]
            elements.forEach {
                view.ex.addEdges([.left, .right], to: $1)
                NSLayoutConstraint.activate([
                    $0.constraint(equalTo: $1.topAnchor),
                    $1.heightAnchor.constraint(equalToConstant: toolbarHeight)
                ])
            }

            let height = toolbarHeight * CGFloat(elements.count)
            tableview.contentInset.top = height
            tableview.scrollIndicatorInsets.top = height
            tableview.setContentOffset(CGPoint(x: 0, y: -height), animated: false)

            pickerToolbar.translatesAutoresizingMaskIntoConstraints = false
            view.insertSubview(pickerToolbar, belowSubview: searchToolbar)
            pickerToolbarTopConstraint.constant = pickerToolbarHeight
            NSLayoutConstraint.activate([
                pickerToolbarTopConstraint,
                pickerToolbar.rightAnchor.constraint(equalTo: view.rightAnchor),
                pickerToolbar.leftAnchor.constraint(equalTo: view.leftAnchor),
                pickerToolbar.heightAnchor.constraint(equalToConstant: pickerToolbarHeight)
            ])
        }

        loadingView.isHidden = true
        view.ex.addEdges(to: loadingView)

        viewModel.reloadData
            .bind(to: Binder(tableview) { tableview, _ in
                tableview.reloadData()
            })
            .disposed(by: disposeBag)

        viewModel.closeKeyboard
            .bind(to: Binder(searchBar) { searchBar, _ in
                searchBar.resignFirstResponder()
            })
            .disposed(by: disposeBag)

        viewModel.showCheckedAlert
            .observeOn(ConcurrentMainScheduler.instance)
            .flatMap { [weak self] element in
                self.map {
                    UIAlertController(title: element.title,
                                      message: element.message,
                                      preferredStyle: .alert)
                        .ex.show(with: element.actions, to: $0)
                } ?? .empty()
            }
            .bind(to: _checkedActionStyle)
            .disposed(by: disposeBag)

        viewModel.scrollTo
            .bind(to: Binder(tableview) { tableview, indexPath in
                tableview.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                tableview.scrollToRow(at: indexPath, at: .top, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak tableview] in
                    tableview?.deselectRow(at: indexPath, animated: true)
                }
            })
            .disposed(by: disposeBag)

        viewModel.clearSearchText
            .bind(to: Binder(searchBar) { searchBar, _ in
                searchBar.text = nil
            })
            .disposed(by: disposeBag)

        viewModel.selectorTitle
            .bind(to: selectorButton.rx.title)
            .disposed(by: disposeBag)

        viewModel.searchTypes
            .bind(to: pickerView.rx.itemTitles) { $1.title }
            .disposed(by: disposeBag)

        viewModel.showPicker
            .bind(to: Binder(self) { me,_ in
                me.keyboardAnimation(topConstant: 0)
            })
            .disposed(by: disposeBag)

        viewModel.hidePicker
            .bind(to: Binder(self) { me, _ in
                me.keyboardAnimation(topConstant: me.pickerToolbarHeight)
            })
            .disposed(by: disposeBag)

        viewModel.keyboardType
            .bind(to: Binder(searchBar) { $0.keyboardType = $1 })
            .disposed(by: disposeBag)

        viewModel.deselectIndexPath
            .bind(to: Binder(tableview) {
                $0.deselectRow(at: $1, animated: true)
            })
            .disposed(by: disposeBag)

        viewModel.hideLoading
            .bind(to: loadingView.rx.isHidden)
            .disposed(by: disposeBag)

        viewModel.showDetail
            .bind(to: Binder(self) { me, _ in
                let vc = ParticipantListDetailViewController(viewModel: me.viewModel)
                let nc = UINavigationController(rootViewController: vc)
                me.present(nc, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
    }

    private func keyboardAnimation(topConstant: CGFloat) {
        view.layoutIfNeeded()
        pickerToolbarTopConstraint.constant = topConstant
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if OS.current == .ios10 {
            do {
                let size = searchToolbar.bounds.size
                searchBar.frame.size = CGSize(width: size.width - 40, height: size.height)
            }
            do {
                let size = pickerToolbar.bounds.size
                pickerView.frame.size = CGSize(width: size.width - 40, height: size.height)
            }
        }
    }
}

extension ParticipantListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.participants.value.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableview.dequeueReusableCell(withIdentifier: ParticipantCell.identifier, for: indexPath)
        if let cell = cell as? ParticipantCell {
            cell.configure(with: viewModel.participants.value[indexPath.row])
        }
        return cell
    }
}
