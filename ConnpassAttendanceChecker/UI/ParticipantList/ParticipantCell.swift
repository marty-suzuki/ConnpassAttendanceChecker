//
//  ParticipantCell.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit
import Kingfisher

final class ParticipantCell: UITableViewCell {
    static let identifier = "ParticipantCell"

    @IBOutlet private weak var numberLabel: UILabel!
    @IBOutlet private weak var displayNameLabel: UILabel!
    @IBOutlet private weak var userNameLabel: UILabel!
    @IBOutlet private weak var checkLabel: UILabel!
    @IBOutlet private weak var thumbnail: UIImageView!

    @IBOutlet private weak var numberCaption: UILabel! {
        didSet { numberCaption.text = "\(String.ex.localized(.number)):" }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnail.kf.cancelDownloadTask()
    }

    func configure(with participant: Participant) {
        numberLabel.text = "\(participant.number)"
        displayNameLabel.text = participant.displayName
        userNameLabel.text = "(\(participant.userName))"
        checkLabel.text = participant.isChecked ? "✅" : "□"
        if let url = URL(string: participant.thumbnail) {
            let resource = ImageResource(downloadURL: url)
            thumbnail.kf.setImage(with: resource)
        }
    }
}
