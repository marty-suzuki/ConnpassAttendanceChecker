//
//  EventRegisterViewController.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import WebKit

final class EventRegisterViewController: UIViewController {
    @IBOutlet private weak var webviewContainer: UIView!
    @IBOutlet private weak var textFeildTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var textFeild: UITextField! {
        didSet {
            textFeild.inputAccessoryView = toolbar
            textFeild.keyboardType = .numberPad
        }
    }

    private let webview = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    private let closeButton = UIBarButtonItem(title: "Close", style: .plain, target: nil, action: nil)
    private let cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: nil, action: nil)
    private let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: nil, action: nil)
    private lazy var toolbar: UIToolbar = {
        let toolbar = UIToolbar(frame: .zero)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.setItems([cancelButton, spacer, doneButton], animated: false)
        return toolbar
    }()

    private lazy var viewModel: EventRegisterViewModel = {
        return .init(cancelButtonTap: self.cancelButton.rx.tap.asObservable(),
                     doneButtonTap: self.doneButton.rx.tap.asObservable(),
                     closeButtonTap: self.closeButton.rx.tap.asObservable(),
                     textFeildValue: self.textFeild.rx.text.asObservable(),
                     isLoading: self.webview.rx.loading,
                     title: self.webview.rx.title,
                     actionStyle: self.actionStyle.asObservable())
    }()
    private let actionStyle = PublishRelay<AlertActionStyle>()
    private let disoseBag = DisposeBag()

    init() {
        super.init(nibName: "EventRegisterViewController", bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = closeButton
        webviewContainer.ex.addEdges(to: webview)

        let constant = textFeildTopConstraint.constant
        textFeild.removeConstraint(textFeildTopConstraint)
        textFeildTopConstraint = textFeild.topAnchor.constraint(equalTo: ex.topAnchor,
                                                                constant: constant)
        textFeildTopConstraint.isActive = true

        viewModel.closeKeyboad
            .bind(to: Binder(textFeild) { textFeild, _ in
                textFeild.resignFirstResponder()
            })
            .disposed(by: disoseBag)

        viewModel.loadRequest
            .bind(to: Binder(webview) { webview, request in
                webview.load(request)
            })
            .disposed(by: disoseBag)

        viewModel.showAlert
            .flatMap { [weak self] message in
                self.map {
                    UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
                        .ex.show(with: [.default("YES"), .destructive("NO")], to: $0)
                } ?? .empty()
            }
            .bind(to: actionStyle)
            .disposed(by: disoseBag)

        viewModel.close
            .bind(to: Binder(self) { me, _ in
                me.dismiss(animated: true, completion: nil)
            })
            .disposed(by: disoseBag)
    }
}
