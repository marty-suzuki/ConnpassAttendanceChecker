//
//  LoadingView.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/10.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit

final class LoadingView: UIView {
    let indicatorView = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)

    override var isHidden: Bool {
        didSet {
            if isHidden {
                indicatorView.stopAnimating()
            } else {
                indicatorView.startAnimating()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.4)
        addSubview(indicatorView)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        indicatorView.center = center
    }
}
