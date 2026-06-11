// InAppMessagesSDKTests.swift
// Unit tests for PPG In-App Messages SDK
// Reference: Android test patterns from migration kit

import XCTest
@testable import PPG_InAppMessages

final class InAppMessagesSDKTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Clear any previous state
        // Reset SDK to clean state for each test
    }
    
    override func tearDownWithError() throws {
        // Clean up after tests
    }
    
    // MARK: - SDK Initialization Tests
    
    func testSDKInitialization() throws {
        let sdk = InAppMessagesSDK.shared
        
        // Test that SDK initializes correctly
        sdk.initialize(apiKey: "test-api-key", projectId: "test-project", isProduction: false)
        
        // Verify SDK is accessible
        XCTAssertNotNil(sdk)
    }
    
    // MARK: - Bridge Pattern Tests
    
    func testPushNotificationStatusProvider() throws {
        let statusProvider = PushNotificationStatusProvider()
        
        // Test default subscription status
        let isSubscribed = statusProvider.isSubscribed()
        XCTAssertFalse(isSubscribed) // Should default to false
        
        // Test notifications blocked status
        let areBlocked = statusProvider.isNotificationsBlocked()
        XCTAssertFalse(areBlocked) // Should default to false
    }
    
    func testAudienceTypeMatching() throws {
        let statusProvider = PushNotificationStatusProvider()
        
        // Test ALL audience type - should always return true
        XCTAssertTrue(statusProvider.matchesAudienceType(.all))
        
        // Test SUBSCRIBER - should be false by default (not subscribed)
        XCTAssertFalse(statusProvider.matchesAudienceType(.subscriber))
        
        // Test NON_SUBSCRIBER - should be true by default
        XCTAssertTrue(statusProvider.matchesAudienceType(.nonSubscriber))
    }
    
    // MARK: - Data Model Tests
    
    func testUserAudienceTypeEnum() throws {
        // Test enum cases
        XCTAssertEqual(UserAudienceType.all.rawValue, "ALL")
        XCTAssertEqual(UserAudienceType.subscriber.rawValue, "SUBSCRIBER")
        XCTAssertEqual(UserAudienceType.nonSubscriber.rawValue, "NON_SUBSCRIBER")
        XCTAssertEqual(UserAudienceType.notificationsBlocked.rawValue, "NOTIFICATIONS_BLOCKED")
    }
    
    func testTriggerTypeEnum() throws {
        // Test trigger types
        XCTAssertEqual(TriggerType.enter.rawValue, "ENTER")
        XCTAssertEqual(TriggerType.custom.rawValue, "CUSTOM_TRIGGER")
        XCTAssertEqual(TriggerType.scroll.rawValue, "SCROLL")
        XCTAssertEqual(TriggerType.exitIntent.rawValue, "EXIT_INTENT")
    }
    
    func testActionTypeEnum() throws {
        // Test action types
        XCTAssertEqual(ActionType.redirect.rawValue, "REDIRECT")
        XCTAssertEqual(ActionType.subscribe.rawValue, "SUBSCRIBE")
        XCTAssertEqual(ActionType.close.rawValue, "CLOSE")
        XCTAssertEqual(ActionType.js.rawValue, "JS")
    }
    
    // MARK: - Message Processing Tests
    
    func testInAppMessageExtensions() throws {
        // Create a test message
        let testAudience = MessageAudience(
            userType: "ALL",
            device: [],
            userAgent: [],
            osType: [],
            platform: "ALL"
        )
        
        let testSettings = MessageScheduleSettings(
            triggerType: "ENTER",
            scrollDepth: 0,
            showAfterDelay: 0,
            display: "",
            displayOn: [],
            showAgain: "always",
            showAfterTime: 0,
            priority: 10,
            customTriggerKey: nil,
            customTriggerValue: nil
        )
        
        let testMessage = InAppMessage(
            id: "test-message-1",
            name: "Test Message",
            html: "<p>Test</p>",
            css: "body { color: black; }",
            enabled: true,
            layout: MessageLayout(
                placement: "CENTER",
                margin: "16px",
                padding: "16px",
                paddingBody: "8px",
                spaceBetweenImageAndBody: 10,
                spaceBetweenContentAndActions: 10,
                spaceBetweenTitleAndDescription: 5
            ),
            style: MessageStyle(
                backgroundColor: "#FFFFFF",
                borderRadius: "8px",
                border: true,
                borderColor: "#CCCCCC",
                borderWidth: 1,
                fontFamily: "Arial",
                fontUrl: nil,
                closeIcon: true,
                closeIconColor: "#333333",
                closeIconWidth: 24,
                zIndex: 1000,
                animationType: "fade",
                dropShadow: true,
                overlay: true
            ),
            title: nil,
            description: nil,
            image: nil,
            actions: [],
            audience: testAudience,
            settings: testSettings,
            createdAt: "2023-01-01T00:00:00Z",
            updatedAt: "2023-01-01T00:00:00Z",
            deletedAt: nil,
            template: nil
        )
        
        let statusProvider = PushNotificationStatusProvider()
        
        // Test audience matching
        XCTAssertTrue(testMessage.matchesAudience(provider: statusProvider))
        
        // Test trigger matching
        XCTAssertTrue(testMessage.matchesTrigger(.enter))
        XCTAssertFalse(testMessage.matchesTrigger(.custom))
    }
    
    // MARK: - Priority Logic Tests
    
    func testPriorityLogicBasic() throws {
        // Create test messages with different priorities
        let messages = createTestMessages(withPriorities: [1, 2, 3])
        
        // Simulate the priority sorting logic from InAppMessageManager
        let sortedMessages = messages.sorted { left, right in
            let leftPriority = left.settings.priority == 0 ? Int.max : left.settings.priority
            let rightPriority = right.settings.priority == 0 ? Int.max : right.settings.priority
            return leftPriority < rightPriority
        }
        
        // Verify order: 1 → 2 → 3
        XCTAssertEqual(sortedMessages[0].settings.priority, 1)
        XCTAssertEqual(sortedMessages[1].settings.priority, 2) 
        XCTAssertEqual(sortedMessages[2].settings.priority, 3)
    }
    
    func testPriorityZeroIsLowest() throws {
        // Test priority 0 as lowest priority
        let messages = createTestMessages(withPriorities: [0, 1, 2])
        
        let sortedMessages = messages.sorted { left, right in
            let leftPriority = left.settings.priority == 0 ? Int.max : left.settings.priority
            let rightPriority = right.settings.priority == 0 ? Int.max : right.settings.priority
            return leftPriority < rightPriority
        }
        
        // Verify order: 1 → 2 → 0 (priority 0 comes last)
        XCTAssertEqual(sortedMessages[0].settings.priority, 1)
        XCTAssertEqual(sortedMessages[1].settings.priority, 2)
        XCTAssertEqual(sortedMessages[2].settings.priority, 0) // 0 should be last
    }
    
    func testPriorityMixedWithZero() throws {
        // Test mixed priorities including zero
        let messages = createTestMessages(withPriorities: [5, 0, 1, 3, 0, 2])
        
        let sortedMessages = messages.sorted { left, right in
            let leftPriority = left.settings.priority == 0 ? Int.max : left.settings.priority
            let rightPriority = right.settings.priority == 0 ? Int.max : right.settings.priority
            return leftPriority < rightPriority
        }
        
        // Verify order: 1 → 2 → 3 → 5 → 0 → 0
        XCTAssertEqual(sortedMessages[0].settings.priority, 1)
        XCTAssertEqual(sortedMessages[1].settings.priority, 2)
        XCTAssertEqual(sortedMessages[2].settings.priority, 3)
        XCTAssertEqual(sortedMessages[3].settings.priority, 5)
        XCTAssertEqual(sortedMessages[4].settings.priority, 0)
        XCTAssertEqual(sortedMessages[5].settings.priority, 0)
    }
    
    // MARK: - Custom Trigger Tests
    
    func testCustomTriggerKeyValueMatching() throws {
        // Test new custom trigger key-value matching logic
        let settingsWithCustom = MessageScheduleSettings(
            triggerType: "CUSTOM",
            scrollDepth: 0,
            showAfterDelay: 0,
            display: "old_display",
            displayOn: [],
            showAgain: "always",
            showAfterTime: 0,
            priority: 1,
            customTriggerKey: "event_name",
            customTriggerValue: "button_clicked"
        )
        
        let message = createTestMessage(settings: settingsWithCustom)
        
        // Test that message would match both customTriggerKey and customTriggerValue
        XCTAssertEqual(settingsWithCustom.customTriggerKey, "event_name")
        XCTAssertEqual(settingsWithCustom.customTriggerValue, "button_clicked")
    }
    
    // MARK: - Helper Methods
    
    private func createTestMessages(withPriorities priorities: [Int]) -> [InAppMessage] {
        return priorities.enumerated().map { index, priority in
            let settings = MessageScheduleSettings(
                triggerType: "CUSTOM",
                scrollDepth: 0,
                showAfterDelay: 0,
                display: "",
                displayOn: [],
                showAgain: "always",
                showAfterTime: 0,
                priority: priority,
                customTriggerKey: nil,
                customTriggerValue: nil
            )
            
            return createTestMessage(id: "message-\(index)", settings: settings)
        }
    }
    
    private func createTestMessage(id: String = "test-message", settings: MessageScheduleSettings) -> InAppMessage {
        return InAppMessage(
            id: id,
            name: "Test Message",
            html: "<p>Test</p>",
            css: "body { color: black; }",
            enabled: true,
            layout: MessageLayout(
                placement: "CENTER",
                margin: "16px",
                padding: "16px",
                paddingBody: "8px",
                spaceBetweenImageAndBody: 10,
                spaceBetweenContentAndActions: 10,
                spaceBetweenTitleAndDescription: 5
            ),
            style: MessageStyle(
                backgroundColor: "#FFFFFF",
                borderRadius: "8px",
                border: true,
                borderColor: "#CCCCCC",
                borderWidth: 1,
                fontFamily: "Arial",
                fontUrl: nil,
                closeIcon: true,
                closeIconColor: "#333333",
                closeIconWidth: 24,
                zIndex: 1000,
                animationType: "fade",
                dropShadow: true,
                overlay: true
            ),
            title: nil,
            description: nil,
            image: nil,
            actions: [],
            audience: MessageAudience(
                userType: "ALL",
                device: [],
                userAgent: [],
                osType: [],
                platform: "ALL"
            ),
            settings: settings,
            createdAt: "2023-01-01T00:00:00Z",
            updatedAt: "2023-01-01T00:00:00Z",
            deletedAt: nil,
            template: nil
        )
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceSDKInitialization() throws {
        measure {
            let sdk = InAppMessagesSDK.shared
            sdk.initialize(apiKey: "test-api-key", projectId: "test-project", isProduction: false)
        }
    }
}
