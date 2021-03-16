//
//  UNNotificationAttachment+Init.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 06/08/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import Foundation
import UserNotifications

extension UNNotificationAttachment {

    convenience init?(url: String) throws {
        let fileManager = FileManager.default
        let temporaryFolderName = ProcessInfo.processInfo.globallyUniqueString
        let temporaryFolderURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(temporaryFolderName, isDirectory: true)

        try fileManager.createDirectory(at: temporaryFolderURL, withIntermediateDirectories: true, attributes: nil)
        
        guard let dotIndex = url.lastIndex(where: { $0 == "." })
            else { return nil }
        let imageExtension = url[dotIndex..<url.endIndex]
        let imageFileIdentifier = UUID().uuidString + imageExtension
        let fileURL = temporaryFolderURL.appendingPathComponent(imageFileIdentifier)
        
        guard let imageData = try? Data(contentsOf: URL(string: url)!) else {
            return nil
        }
        
        try imageData.write(to: fileURL)
        try self.init(identifier: imageFileIdentifier, url: fileURL, options: [:])
    }
}
