//
//  Enums.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 13/07/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import Foundation

public enum ActionResult {
    case success
    case error(String)
}

public enum EventType: String, Codable {
    case clicked
    case delivered
}

public enum pushActions: String {
    case firstButton
    case secondButton
}

enum pushCategories: String {
    case oneButtonCategory
    case twoButtonsCategory
}
