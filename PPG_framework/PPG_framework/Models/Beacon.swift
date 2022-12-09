//
//  Beacon.swift
//  PPG_framework
//
//  Created by Adam Majczyk on 16/07/2020.
//  Copyright © 2020 Goodylabs. All rights reserved.
//

import Foundation

public class Beacon {

    public var selectors: [BeaconSelector]
    public var tags: [BeaconTag]
    public var tagsToDelete: [BeaconTag]
    public var customId: String
    
    public init() {
        selectors = []
        tags = []
        tagsToDelete = []
        customId = ""
    }
    
    public func addTag(_ tag: String, _ label: String) {
        tags.append(BeaconTag(tag: tag, label: label))
    }

    public func addTag(_ tag: BeaconTag) {
        tags.append(tag)
    }
    
    public func addTags(_ tags: [BeaconTag]) {
        self.tags.append(contentsOf: tags)
    }
    
    public func addTagToDelete(_ tag: BeaconTag) {
        self.tagsToDelete.append(tag)
    }
    
    public func addTagsToDelete(_ tags: [BeaconTag]) {
        self.tagsToDelete.append(contentsOf: tags)
    }
    
    public func addSelector(_ selector: BeaconSelector) {
        self.selectors.append(selector)
    }
    
    public func addSelector(_ name: String, _ value: String) {
        let tmpSelector = BeaconSelector(name: name, value: value)
        self.selectors.append(tmpSelector)
    }
    
    public func addSelector(_ name: String, _ value: Float) {
        let tmpSelector = BeaconSelector(name: name, value: value)
        self.selectors.append(tmpSelector)
    }
    
    public func addSelector(_ name: String, _ value: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        let formattedDate = formatter.string(from: value) + "Z"
        let tmpSelector = BeaconSelector(name: name, value: formattedDate)
        self.selectors.append(tmpSelector)
    }
    
    //2021-02-03T08:12:01.023Z
    
    public func addSelector(_ name: String, _ value: Bool) {
        let tmpSelector = BeaconSelector(name: name, value: value)
        self.selectors.append(tmpSelector)
    }
    
    public func addSelectors(_ selectors: [BeaconSelector]) {
        self.selectors.append(contentsOf: selectors)
    }
    
    public func send(handler:@escaping (_ result: ActionResult) -> Void) {
        ApiService.shared.sendBeacon(beacon: self) { result in
            handler(result)
        }
    }
}

public struct BeaconTag: Codable {

    public let tag: String
    public let label: String

    public init(tag: String, label: String) {
        self.tag = tag
        self.label = label
    }
}

public struct BeaconSelector: Codable {
    let selectorName: String
    let selectorValue: AnyCodableValue
    
    init(name: String, value: Float) {
        selectorName = name
        selectorValue = AnyCodableValue(value: value)
    }
    
    init(name: String, value: String) {
        selectorName = name
        selectorValue = AnyCodableValue(value: value)
    }
    
    init(name: String, value: Date) {
        selectorName = name
        selectorValue = AnyCodableValue(value: value)
    }
    
    init(name: String, value: Bool) {
        selectorName = name
        selectorValue = AnyCodableValue(value: value)
    }
}

public struct AnyCodableValue: Codable {
    var numberValue: Float?
    var stringValue: String?
    var dateValue: Date?
    var boolValue: Bool?
    
    var type: CodableType

    init(value: Float) {
        numberValue = value
        type = .number
    }
    
    init(value: String) {
        stringValue = value
        type = .string
    }
    
    init(value: Bool) {
        boolValue = value
        type = .bool
    }
    
    init(value: Date) {
        dateValue = value
        type = .date
    }
    
    public func get() -> Any {
        switch type {
        case .number:
            return numberValue ?? 0
        case .string:
            return stringValue ?? ""
        case .date:
            return dateValue ?? Date()
        case .bool:
            return boolValue ?? false
        }
    }
}

enum CodableType: String, Codable {
    case number, string, date, bool
}
