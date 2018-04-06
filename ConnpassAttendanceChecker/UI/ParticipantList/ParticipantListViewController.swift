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
    private lazy var webview: WKWebView = {
        let config = WKWebViewConfiguration()
        config.processPool = viewModel.processPool.value
        return WKWebView(frame: .zero, configuration: config)
    }()

    private let event: Event
    private let disposeBag = DisposeBag()
    private let _navigationAction = PublishRelay<WKNavigationAction>()
    private var navigationActionPolicyDisposeBag = DisposeBag()
    private let _htmlDocument = PublishRelay<HTMLDocument>()
    private let _isLoading = PublishRelay<Bool>()
    private lazy var viewModel = ParticipantListViewModel(event: self.event,
                                                          viewDidAppear: self.ex.viewDidAppear,
                                                          navigationAction: self._navigationAction.asObservable(),
                                                          htmlDocument: self._htmlDocument.asObservable(),
                                                          loading: self._isLoading.asObservable())

    init(event: Event) {
        self.event = event
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Participant List"

        tableview.dataSource = self
        tableview.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        view.ex.addEdges(to: tableview)

        webview.navigationDelegate = self

        webview.rx.loading
            .bind(to: _isLoading)
            .disposed(by: disposeBag)

        viewModel.participantsURL
            .bind(to: Binder(webview) { webview, url in
                webview.load(URLRequest(url: url))
            })
            .disposed(by: disposeBag)

        viewModel.showLogin
            .bind(to: Binder(self) { me, processPool in
                let vc = LoginViewController(processPool: processPool)
                let nc = UINavigationController(rootViewController: vc)
                me.present(nc, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)

        viewModel.getHTMLDocument
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
    }
}

extension ParticipantListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.participants.value.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableview.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = viewModel.participants.value[indexPath.row].userName
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
}
