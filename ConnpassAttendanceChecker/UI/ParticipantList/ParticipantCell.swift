//
//  ParticipantCell.swift
//  ConnpassAttendanceChecker
//
//  Created by marty-suzuki on 2018/04/07.
//  Copyright © 2018年 marty-suzuki. All rights reserved.
//

import UIKit

final class ParticipantCell: UITableViewCell {
    static let identifier = "ParticipantCell"

    @IBOutlet private weak var numberLabel: UILabel!
    @IBOutlet private weak var displayNameLabel: UILabel!
    @IBOutlet private weak var userNameLabel: UILabel!
    @IBOutlet private weak var checkLabel: UILabel!

    @IBOutlet private weak var numberCaption: UILabel! {
        didSet { numberCaption.text = String.ex.localized(.number) }
    }
    @IBOutlet private weak var displayNameCaption: UILabel! {
        didSet { displayNameCaption.text = String.ex.localized(.displayName) }
    }
    @IBOutlet private weak var userNameCaption: UILabel! {
        didSet { userNameCaption.text = String.ex.localized(.userName) }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func configure(with participant: Participant) {
        numberLabel.text = "\(participant.number)"
        displayNameLabel.text = participant.displayName
        userNameLabel.text = participant.userName
        checkLabel.text = participant.isChecked ? "✅" : "□"
    }
}
