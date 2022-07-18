////
////  PipeTests.swift
////
////
////  Created by Thibault WITTEMBERG on 20/06/2022.
////
//
//@testable import AsyncStateMachine
//import XCTest
//
//final class PipeTests: XCTestCase {
//  enum Event: DSLCompatible, Equatable {
//    case e1
//  }
//
//  func test_register_sets_the_receiver() async {
//    let expectedEvent = Event.e1
//    var receivedEvent: Event?
//
//    let spyReceiver: (Event) async -> Void = { event in
//      receivedEvent = event
//    }
//
//    // Given
//    let sut = AsyncStateMachine.Pipe<Event>()
//    sut.register(receiver: spyReceiver)
//
//    // When
//    await sut.receiver?(expectedEvent)
//
//    // Then
//    XCTAssertEqual(receivedEvent, expectedEvent)
//  }
//
//  func test_ping_calls_the_receiver() async {
//    let expectedEvent = Event.e1
//    var receivedEvent: Event?
//
//    let spyReceiver: (Event) async -> Void = { event in
//      receivedEvent = event
//    }
//
//    // Given
//    let sut = AsyncStateMachine.Pipe<Event>()
//    sut.register(receiver: spyReceiver)
//
//    // When
//    await sut.push(expectedEvent)
//
//    // Then
//    XCTAssertEqual(receivedEvent, expectedEvent)
//  }
//}
