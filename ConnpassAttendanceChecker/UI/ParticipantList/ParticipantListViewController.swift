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
    private let refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: nil, action: nil)
    private let selectorButton = UIBarButtonItem(title: nil, style: .plain, target: nil, action: nil)
    private let pickerView = UIPickerView(frame: .zero)
    private let loadingView = LoadingView(frame: .zero)
    private lazy var webview: WKWebView = {
        let config = WKWebViewConfiguration()
        config.processPool = self.processPool
        return WKWebView(frame: .zero, configuration: config)
    }()
    private lazy var searchBar: UISearchBar = {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.showsCancelButton = true
        return searchBar
    }()
    private lazy var searchToolbar: UIToolbar = {
        let toolbar = UIToolbar(frame: .zero)
        toolbar.clipsToBounds = true
        self.searchBar.translatesAutoresizingMaskIntoConstraints = false
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
        self.pickerView.translatesAutoresizingMaskIntoConstraints = false
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
    private let _navigationAction = PublishRelay<WKNavigationAction>()
    private let _didFinishNavigation = PublishRelay<Void>()
    private var navigationActionPolicyDisposeBag = DisposeBag()
    private let _htmlDocument = PublishRelay<HTMLDocument>()
    private let _isLoading = PublishRelay<Bool>()
    private let _checkedActionStyle = PublishRelay<AlertActionStyle>()
    private lazy var viewModel = ParticipantListViewModel(event: self.event,
                                                          viewDidAppear: self.ex.viewDidAppear,
                                                          navigationAction: self._navigationAction.asObservable(),
                                                          htmlDocument: self._htmlDocument.asObservable(),
                                                          loading: self._isLoading.asObservable(),
                                                          searchText: self.searchBar.rx.text.asObservable(),
                                                          cancelButtonTap: self.searchBar.rx.cancelButtonClicked.asObservable(),
                                                          searchButtonTap: self.searchBar.rx.searchButtonClicked.asObservable(),
                                                          selectorButtonTap: self.selectorButton.rx.tap.asObservable(),
                                                          refreshButtonTap: self.refreshButton.rx.tap.asObservable(),
                                                          checkedActionStyle: self._checkedActionStyle.asObservable(),
                                                          pickerItemSelected: self.pickerView.rx.itemSelected.asObservable(),
                                                          tableViewItemSelected:  self.tableview.rx.itemSelected.asObservable(),
                                                          didFinishNavigation: self._didFinishNavigation.asObservable(),
                                                          loggedOut: self.loggedOut)

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

        navigationItem.title = "Participant List"
        navigationItem.rightBarButtonItem = refreshButton

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

        webview.navigationDelegate = self

        webview.rx.loading
            .bind(to: _isLoading)
            .disposed(by: disposeBag)

        viewModel.participantsURL
            .bind(to: Binder(webview) { webview, url in
                webview.load(URLRequest(url: url))
            })
            .disposed(by: disposeBag)

        viewModel.getHTMLDocument
            .observeOn(MainScheduler.instance)
            .flatMapLatest { [weak webview] _ in
                webview.map { $0.rx.html() } ?? .empty()
            }
            .bind(to: _htmlDocument)
            .disposed(by: disposeBag)

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

        viewModel.enableRefresh
            .bind(to: refreshButton.rx.isEnabled)
            .disposed(by: disposeBag)

        viewModel.close
            .bind(to: Binder(self) { me, _ in
                me.navigationController?.popViewController(animated: true)
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

extension ParticipantListViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        navigationActionPolicyDisposeBag = DisposeBag()

        viewModel.navigationActionPolicy
            .bind(onNext: decisionHandler)
            .disposed(by: navigationActionPolicyDisposeBag)

        _navigationAction.accept(navigationAction)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        _didFinishNavigation.accept(())
    }
}
