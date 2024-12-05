//
//  PPG_frameworkTests.swift
//  PPG_frameworkTests
//
//  Created by Adam Majczyk on 13/07/2020.
//  Copyright 2020 Goodylabs. All rights reserved.
//

import XCTest
@testable import PPG_framework

class PPG_frameworkTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Setup code before each test method is invoked.
    }
    
    override func tearDownWithError() throws {
        // Teardown code after each test method is invoked.
    }
    
    func testEventManager() throws {
        let expectation1 = expectation(description: "Event 1 registered")
        let expectation2 = expectation(description: "Event 2 registered")
        let mockSender = MockEventSender()
        let eventManager = EventManager(sharedData: SharedData.shared, eventSender: mockSender)
        eventManager.clearEvents()
        
        let eventDelivered1 = Event(eventType: .delivered, button: nil, campaign: "1,2,3")
        let eventDelivered2 = Event(eventType: .delivered, button: nil, campaign: "1,2,3")
        
        XCTAssertFalse(eventDelivered1.wasSent())
        XCTAssertFalse(eventDelivered2.wasSent())
        
        eventManager.register(event: eventDelivered1) { result in
            print("eventDelivered1 register result: \(result)")
            // Fetch the event from EventManager's storage
            let events = eventManager.getEvents().filter { $0.softEquals(eventDelivered1) }
            XCTAssertEqual(events.count, 1)
            XCTAssertTrue(events[0].wasSent())
            XCTAssertNotNil(events[0].sentAt)
            print("Event sentAt: \(events[0].sentAt!)")
            expectation1.fulfill()
        }
        
        eventManager.register(event: eventDelivered2) { result in
            print("eventDelivered2 register result: \(result)")
            if case .error(let message) = result {
                XCTAssertEqual(message, "Event was sent before. Omitting")
                XCTAssertFalse(eventDelivered2.wasSent())
            } else {
                XCTFail("Expected an error for duplicate event")
            }
            expectation2.fulfill()
        }
        
        wait(for: [expectation1, expectation2], timeout: 5.0)
    }
    
    func testEventManagerSync() throws {
        let expectation = XCTestExpectation(description: "All events registered")
        let mockSender = MockEventSender()
        let eventManager = EventManager(sharedData: SharedData.shared, eventSender: mockSender)
        eventManager.clearEvents()
        
        var events: [Event] = []
        
        for _ in 0..<10 {
            events.append(Event(eventType: .delivered, button: nil, campaign: "1,2,3"))
        }
        
        let tasks = events.map { event in
            return { (completion: @escaping (String) -> Void) in
                eventManager.register(event: event) { result in
                    switch result {
                    case .success:
                        return completion("Success")
                    case .error:
                        return completion("Error")
                    }
                }
            }
        }
        
        TestUtils.promiseAll(tasks: tasks) {results in
            XCTAssertEqual(results.filter { $0 == "Success" }.count, 1)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSetEvents() throws {
        let expectation = XCTestExpectation(description: "Event registered")
        let mockSender = MockEventSender()
        let eventManager = EventManager(sharedData: SharedData.shared, eventSender: mockSender)
        eventManager.clearEvents()
        
        let eventDelivered1 = Event(eventType: .delivered, button: nil, campaign: "1,2,3")
        eventDelivered1.sentAt = Date()
        
        let eventDelivered2 = Event(eventType: .delivered, button: nil, campaign: "1,2,3")
        eventManager.setEvents(events: [eventDelivered1])
        eventManager.register(event: eventDelivered2) { result in
            print("eventDelivered2 register result: \(result)")
            if case .error(let message) = result {
                XCTAssertEqual(message, "Event was sent before. Omitting")
                XCTAssertFalse(eventDelivered2.wasSent())
            } else {
                XCTFail("Expected an error for duplicate event")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSyncEvents() throws {
        let expectation = XCTestExpectation(description: "Sync events completed")
        let mockSender = MockEventSender()
        let eventManager = EventManager(sharedData: SharedData.shared, eventSender: mockSender)
        eventManager.clearEvents()
        
        let eventDelivered1 = Event(eventType: .delivered, button: nil, campaign: "1")
        eventDelivered1.sentAt = Date()
        
        let eventDelivered2 = Event(eventType: .delivered, button: nil, campaign: "1,2")
        eventDelivered2.sentAt = Date().addingTimeInterval(-1 * 14 * 24 * 60 * 60)
        
        let eventDelivered3 = Event(eventType: .delivered, button: nil, campaign: "1,2,3")
        
        eventManager.setEvents(events: [eventDelivered1, eventDelivered2, eventDelivered3])
        
        eventManager.sync() { events in
            print(events.map{
                $0.debug()
            })
            XCTAssertEqual(events.count, 2)
            XCTAssertTrue(events[0].wasSent())
            XCTAssertTrue(events[1].wasSent())
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

class TestUtils {
    // Mimicking Promise.all with DispatchGroup
    static func promiseAll(tasks: [(@escaping (String) -> Void) -> Void], handler: @escaping ([String]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var results: [String] = []
        
        for task in tasks {
            dispatchGroup.enter()
            task { result in
                results.append(result)
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
            handler(results)
        }
    }
}
