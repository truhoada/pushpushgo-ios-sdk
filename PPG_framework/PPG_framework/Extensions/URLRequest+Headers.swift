//
//  URLRequest+Headers.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 16/07/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import Foundation

extension URLRequest {

    mutating func addStandardHeaders() {
        self.setValue("application/json", forHTTPHeaderField: "Content-Type")
        self.setValue(SharedData.shared.apiToken, forHTTPHeaderField: "X-Token")
    }
}
