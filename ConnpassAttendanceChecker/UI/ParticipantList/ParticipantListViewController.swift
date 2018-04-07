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
    private lazy var numberSearchField: UITextField = {
        let textFeild = UITextField(frame: .zero)
        textFeild.borderStyle = .roundedRect
        textFeild.keyboardType = .numberPad
        textFeild.placeholder = "Seach Number..."
        let toolbar = UIToolbar(frame: .zero)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.setItems([self.cancelButton, spacer, self.searchButton], animated: false)
        textFeild.inputAccessoryView = toolbar
        return textFeild
    }()
    private lazy var searchToolbar: UIToolbar = {
        let toolbar = UIToolbar(frame: .zero)
        self.numberSearchField.translatesAutoresizingMaskIntoConstraints = false
        let textFeild = UIBarButtonItem(customView: self.numberSearchField)
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.setItems([textFeild, spacer, self.cameraButton], animated: false)
        return toolbar
    }()
    private let searchButton = UIBarButtonItem(title: "Search", style: .plain, target: nil, action: nil)
    private let cameraButton = UIBarButtonItem(barButtonSystemItem: .camera, target: nil, action: nil)
    private let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: nil, action: nil)

    private let event: Event
    private let disposeBag = DisposeBag()
    private let _navigationAction = PublishRelay<WKNavigationAction>()
    private var navigationActionPolicyDisposeBag = DisposeBag()
    private let _htmlDocument = PublishRelay<HTMLDocument>()
    private let _isLoading = PublishRelay<Bool>()
    private let _checkedActionStyle = PublishRelay<AlertActionStyle>()
    private lazy var viewModel = ParticipantListViewModel(event: self.event,
                                                          viewDidAppear: self.ex.viewDidAppear,
                                                          navigationAction: self._navigationAction.asObservable(),
                                                          htmlDocument: self._htmlDocument.asObservable(),
                                                          loading: self._isLoading.asObservable(),
                                                          numberText: self.numberSearchField.rx.text.asObservable(),
                                                          cancelButtonTap: self.cancelButton.rx.tap.asObservable(),
                                                          searchButtonTap: self.searchButton.rx.tap.asObservable(),
                                                          cameraButtonTap: self.cameraButton.rx.tap.asObservable(),
                                                          checkedActionStyle: self._checkedActionStyle.asObservable())

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
        let nib = UINib(nibName: ParticipantCell.identifier, bundle: nil)
        tableview.register(nib, forCellReuseIdentifier: ParticipantCell.identifier)
        view.ex.addEdges(to: tableview)

        do {
            let toolbarHeight: CGFloat = 44
            view.ex.addEdges([.left, .right], to: searchToolbar)
            NSLayoutConstraint.activate([
                ex.topAnchor.constraint(equalTo: searchToolbar.topAnchor),
                searchToolbar.heightAnchor.constraint(equalToConstant: toolbarHeight)
            ])
            tableview.contentInset.top = toolbarHeight
            tableview.scrollIndicatorInsets.top = toolbarHeight
            tableview.setContentOffset(CGPoint(x: 0, y: -toolbarHeight), animated: false)
        }

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

        viewModel.closeKeyboard
            .bind(to: Binder(numberSearchField) { textField, _ in
                textField.resignFirstResponder()
            })
            .disposed(by: disposeBag)

        viewModel.showCheckedAlert
            .flatMap { [weak self] element in
                self.map {
                    UIAlertController(title: element.title,
                                      message: element.message,
                                      preferredStyle: .alert)
                        .ex.show(with: [.default("YES"), .destructive("NO")], to: $0)
                } ?? .empty()
            }
            .bind(to: _checkedActionStyle)
            .disposed(by: disposeBag)

        viewModel.scrollTo
            .bind(to: Binder(tableview) { tableview, indexPath in
                tableview.selectRow(at: indexPath, animated: true, scrollPosition: .top)
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak tableview] in
                    tableview?.deselectRow(at: indexPath, animated: true)
                }
            })
            .disposed(by: disposeBag)
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
}
