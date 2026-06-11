//
//  DataHex.swift
//  PPG_LiveActivities
//

import Foundation

extension Data {
    /// Lowercase hex representation — the wire format for APNs tokens.
    var ppgHexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
