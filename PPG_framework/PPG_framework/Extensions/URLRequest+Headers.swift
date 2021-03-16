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
        self.setValue("85558fee-b1a3-47aa-8167-940a4bfe9438", forHTTPHeaderField: "X-Token")
    }
}
