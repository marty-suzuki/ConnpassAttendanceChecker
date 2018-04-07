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
