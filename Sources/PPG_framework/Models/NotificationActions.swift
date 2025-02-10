import Foundation
import UserNotifications

public enum NotificationActionType: String, CaseIterable {
    case button1 = "button_1"
    case button2 = "button_2"
    
    static func identifier(for index: Int) -> String {
        "button_\(index + 1)"
    }
}

public enum NotificationActionOption: String {
    case foreground
    case destructive
    case authenticationRequired
    
    static func fromOptions(_ options: UNNotificationActionOptions) -> [NotificationActionOption] {
        var result: [NotificationActionOption] = []
        if options.contains(.foreground) { result.append(.foreground) }
        if options.contains(.destructive) { result.append(.destructive) }
        if options.contains(.authenticationRequired) { result.append(.authenticationRequired) }
        return result
    }
    
    static func toOptions(_ strings: [String]) -> UNNotificationActionOptions {
        var options: UNNotificationActionOptions = []
        strings.compactMap { NotificationActionOption(rawValue: $0.lowercased()) }
              .forEach { option in
                  switch option {
                  case .foreground: options.insert(.foreground)
                  case .destructive: options.insert(.destructive)
                  case .authenticationRequired: options.insert(.authenticationRequired)
                  }
              }
        return options.isEmpty ? .foreground : options
    }
    
    static func toOptions(_ dict: [String: Any]) -> UNNotificationActionOptions {
        guard let optionsArray = dict["options"] as? [String] else {
            return .foreground
        }
        return toOptions(optionsArray)
    }
}

public struct StoredAction: Codable {
    let identifier: String
    let title: String
    let options: [String]
    
    var notificationOptions: UNNotificationActionOptions {
        NotificationActionOption.toOptions(options)
    }
}

public struct StoredCategory: Codable {
    let id: String
    let timestamp: Date
    let actions: [StoredAction]
    
    static let maxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > Self.maxAge
    }
    
    func toNotificationCategory() -> UNNotificationCategory {
        UNNotificationCategory(
            identifier: id,
            actions: actions.map { action in
                UNNotificationAction(
                    identifier: action.identifier,
                    title: action.title,
                    options: action.notificationOptions
                )
            },
            intentIdentifiers: [],
            options: []
        )
    }
}

public struct CategoryManager {
    public static let defaultCategoryId = "default_notification"
    private static let dynamicCategoriesKey = "PPGDynamicCategories"
    
    static func loadStoredCategories() -> [StoredCategory] {
        guard let data = UserDefaults.standard.data(forKey: dynamicCategoriesKey),
              let storedCategories = try? JSONDecoder().decode([StoredCategory].self, from: data) else {
            return []
        }
        
        let now = Date()
        return storedCategories.filter { !$0.isExpired }
    }
    
    static func saveCategory(id: String, actions: [UNNotificationAction]) {
        var categories = loadStoredCategories()
        categories.removeAll { $0.id == id }
        
        let storedActions = actions.map { action in
            StoredAction(
                identifier: action.identifier,
                title: action.title,
                options: parseOptionsToStrings(from: action.options)
            )
        }
        
        let category = StoredCategory(
            id: id,
            timestamp: Date(),
            actions: storedActions
        )
        
        categories.append(category)
        
        // Remove expired categories
        categories.removeAll { $0.isExpired }
        
        if let data = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(data, forKey: dynamicCategoriesKey)
        }
    }
    
    private static func parseOptionsToStrings(from options: UNNotificationActionOptions) -> [String] {
        NotificationActionOption.fromOptions(options).map { $0.rawValue }
    }
    
    static func addDefaultCategories() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { categories in
            var updatedCategories = categories
            
            // Add default category if it doesn't exist
            if !categories.contains(where: { $0.identifier == defaultCategoryId }) {
                let category = UNNotificationCategory(
                    identifier: defaultCategoryId,
                    actions: [],
                    intentIdentifiers: [],
                    options: []
                )
                updatedCategories.insert(category)
            }
            
            // Add stored categories
            loadStoredCategories().forEach { storedCategory in
                let category = storedCategory.toNotificationCategory()
                updatedCategories.insert(category)
            }
            
            center.setNotificationCategories(updatedCategories)
        }
    }
}

public struct NotificationActionBuilder {
    static func createUniqueActions(from actions: [[String: Any]]) -> [UNNotificationAction] {
        var titleCount: [String: Int] = [:]
        
        return actions.enumerated().map { (index, action) -> UNNotificationAction in
            let baseTitle = action["title"] as? String ?? "Action \(index + 1)"
            let count = titleCount[baseTitle, default: 0]
            let title = count > 0 ? "\(baseTitle) (\(count + 1))" : baseTitle
            titleCount[baseTitle] = count + 1
            
            let identifier = NotificationActionType.identifier(for: index)
            let options = parseOptions(from: action)
            
            return UNNotificationAction(
                identifier: identifier,
                title: title,
                options: options
            )
        }
    }
    
    private static func parseOptions(from action: [String: Any]) -> UNNotificationActionOptions {
        NotificationActionOption.toOptions(action)
    }
}
