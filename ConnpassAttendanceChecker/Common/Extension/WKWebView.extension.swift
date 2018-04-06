//
//  WKWebView.extension.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import Foundation
import WebKit
import RxSwift
import RxCocoa
import Kanna

extension Reactive where Base: WKWebView {
    var title: Observable<String?> {
        return observeWeakly(String.self, "title")
    }

    var loading: Observable<Bool> {
        return observeWeakly(Bool.self, "loading")
            .map { $0 ?? false }
    }

    var estimatedProgress: Observable<Double> {
        return observeWeakly(Double.self, "estimatedProgress")
            .map { $0 ?? 0.0 }
    }

    var url: Observable<URL?> {
        return observeWeakly(URL.self, "URL")
    }

    var canGoBack: Observable<Bool> {
        return observeWeakly(Bool.self, "canGoBack")
            .map { $0 ?? false }
    }

    var canGoForward: Observable<Bool> {
        return self.observeWeakly(Bool.self, "canGoForward")
            .map { $0 ?? false }
    }

    func html() -> Observable<HTMLDocument> {
        return Observable<HTMLDocument>.create { [base] observer in
            base.evaluateJavaScript("document.body.innerHTML") { html, error in
                if let error = error {
                    observer.onError(error)
                    return
                }
                guard let html = html as? String else {
                    observer.onCompleted()
                    return
                }

                do {
                    observer.onNext(try HTML(html: html, encoding: .utf8))
                    observer.onCompleted()
                } catch let e {
                    observer.onError(e)
                }
            }
            return Disposables.create()
            }
            .take(1)
    }
}
