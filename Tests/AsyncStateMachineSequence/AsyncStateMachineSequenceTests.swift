//
//  AsyncJustSequenceTests.swift
//
//
//  Created by Thibault WITTEMBERG on 02/07/2022.
//

@preconcurrency import XCTest
@testable import AsyncStateMachine

final class AsyncStateMachineSequenceTests: XCTestCase {
  func test_asyncStateMachineSequence_delivers_values_when_two_producers_and_two_consumers() async {
    let (sentFromProducer1, sentFromProducer2) = ("test1", "test2")
    let expected = Set([sentFromProducer1, sentFromProducer2])

    let stateMachineSequence = AsyncStateMachineSequence<String>()
    Task {
      await stateMachineSequence.send(sentFromProducer1)
    }
    Task {
      await stateMachineSequence.send(sentFromProducer2)
    }

    let t: Task<String?, Never> = Task {
      var iterator = stateMachineSequence.makeAsyncIterator()
      let value = await iterator.next()
      return value
    }
    var iterator = stateMachineSequence.makeAsyncIterator()

    let (collectedFromConsumer1, collectedFromConsumer2) = (await t.value, await iterator.next())
    let collected = Set([collectedFromConsumer1, collectedFromConsumer2])

    XCTAssertEqual(collected, expected)
  }

  func test_asyncStateMachineSequence_ends_alls_iterators_and_discards_additional_sent_values_when_finish_is_called() async {
    let stateMachineSequence = AsyncStateMachineSequence<String>()
    let complete = ManagedCriticalState(false)
    let finished = expectation(description: "finished")

    Task {
      stateMachineSequence.finish()
      complete.withCriticalRegion { $0 = true }
      finished.fulfill()
    }

    let valueFromConsumer1 = ManagedCriticalState<String?>(nil)
    let valueFromConsumer2 = ManagedCriticalState<String?>(nil)

    let received = expectation(description: "received")
    received.expectedFulfillmentCount = 2

    let pastEnd = expectation(description: "pastEnd")
    pastEnd.expectedFulfillmentCount = 2

    Task {
      var iterator = stateMachineSequence.makeAsyncIterator()
      let ending = await iterator.next()
      valueFromConsumer1.withCriticalRegion { $0 = ending }
      received.fulfill()
      let item = await iterator.next()
      XCTAssertNil(item)
      pastEnd.fulfill()
    }

    Task {
      var iterator = stateMachineSequence.makeAsyncIterator()
      let ending = await iterator.next()
      valueFromConsumer2.withCriticalRegion { $0 = ending }
      received.fulfill()
      let item = await iterator.next()
      XCTAssertNil(item)
      pastEnd.fulfill()
    }

    wait(for: [finished, received], timeout: 1.0)

    XCTAssertTrue(complete.criticalState)
    XCTAssertEqual(valueFromConsumer1.criticalState, nil)
    XCTAssertEqual(valueFromConsumer2.criticalState, nil)

    wait(for: [pastEnd], timeout: 1.0)
    let additionalSend = expectation(description: "additional send")
    Task {
      await stateMachineSequence.send("test")
      additionalSend.fulfill()
    }
    wait(for: [additionalSend], timeout: 1.0)
  }

  func test_asyncStateMachineSequence_ends_iterator_when_task_is_cancelled() async {
    let stateMachineSequence = AsyncStateMachineSequence<String>()
    let ready = expectation(description: "ready")
    let task: Task<String?, Never> = Task {
      var iterator = stateMachineSequence.makeAsyncIterator()
      ready.fulfill()
      return await iterator.next()
    }
    wait(for: [ready], timeout: 1.0)
    task.cancel()
    let value = await task.value
    XCTAssertNil(value)
  }

  func test_asyncStateMachineSequence_resumes_send_when_task_is_cancelled() async {
    let stateMachineSequence = AsyncStateMachineSequence<Int>()
    let notYetDone = expectation(description: "not yet done")
    notYetDone.isInverted = true
    let done = expectation(description: "done")
    let task = Task {
      await stateMachineSequence.send(1)
      notYetDone.fulfill()
      done.fulfill()
    }
    wait(for: [notYetDone], timeout: 0.1)
    task.cancel()
    wait(for: [done], timeout: 1.0)
  }

  func test_computeConsumerDecision_goes_to_awaitingProducer_and_suspend_when_state_is_idle() async {
    // Given
    let stateMachineSequence = AsyncStateMachineSequence<String>()
    stateMachineSequence.state.apply(criticalState: .idle)

    // When
    let consumerDecision = stateMachineSequence.computeConsumerDecision(
      consumerIdentifier: 0,
      continuation: nil
    )

    // Then
    let expectedConsumer = Consumer<String>.placeHolder(identifier: 0)

    if case let .awaitingProducer(consumers) = stateMachineSequence.state.criticalState {
      XCTAssertEqual(consumers.first, expectedConsumer)
    }

    guard case .suspend = consumerDecision else {
      XCTFail("The consumer decision should be .suspend")
      return
    }
  }

  func test_computeConsumerDecision_goes_to_idle_and_resumeImmediately_when_state_is_awaiting_one_consumer() async {
    // Given
    let producer = Producer<String>(continuation: nil)
    let stateMachineSequence = AsyncStateMachineSequence<String>()
    stateMachineSequence.state.apply(criticalState: .awaitingConsumer(producers: [producer]))

    // When
    let consumerDecision = stateMachineSequence.computeConsumerDecision(
      consumerIdentifier: 0,
      continuation: nil
    )

    // Then
    let expectedConsumer = Consumer<String>.placeHolder(identifier: 0)

    guard case .idle = stateMachineSequence.state.criticalState else {
      XCTFail("The state should be .idle")
      return
    }

    guard case let .resumeImmediately(consumer, _) = consumerDecision, consumer == expectedConsumer
    else {
      XCTFail("The consumer decision should be .resumeImmediately")
      return
    }
  }

  func test_computeConsumerDecision_goes_to_awaitingConsumer_and_resumeImmediately_when_state_is_awaiting_several_consumer() async {
    // Given
    let producer1 = Producer<String>(continuation: nil)
    let producer2 = Producer<String>(continuation: nil)

    let stateMachineSequence = AsyncStateMachineSequence<String>()
    stateMachineSequence.state.apply(criticalState: .awaitingConsumer(producers: [producer1, producer2]))

    // When
    let consumerDecision = stateMachineSequence.computeConsumerDecision(
      consumerIdentifier: 0,
      continuation: nil
    )

    // Then
    let expectedConsumer = Consumer<String>.placeHolder(identifier: 0)

    guard case let .awaitingConsumer(producers) = stateMachineSequence.state.criticalState, producers.count == 1 else {
      XCTFail("The state should be .awaitingConsumer with one producer")
      return
    }

    guard case let .resumeImmediately(consumer, _) = consumerDecision, consumer == expectedConsumer else {
      XCTFail("The consumer decision should be .resumeImmediately")
      return
    }
  }

  func test_computeConsumerDecision_goes_to_awaitingProducer_and_suspend_when_state_is_awaitingProducer() async {
    let expectedConsumer1 = Consumer<String>.placeHolder(identifier: 0)
    let expectedConsumer2 = Consumer<String>.placeHolder(identifier: 1)

    // Given
    let stateMachineSequence = AsyncStateMachineSequence<String>()
    stateMachineSequence.state.apply(criticalState: .awaitingProducer(consumers: [expectedConsumer1]))

    // When
    let consumerDecision = stateMachineSequence.computeConsumerDecision(
      consumerIdentifier: 1,
      continuation: nil
    )

    // Then
    guard
      case let .awaitingProducer(consumers) = stateMachineSequence.state.criticalState,
      consumers.count == 2,
      consumers == [expectedConsumer1, expectedConsumer2] else {
      XCTFail("The state should be .awaitingProducer with two consumers")
      return
    }

    guard case .suspend = consumerDecision else {
      XCTFail("The consumer decision should be .resumeImmediately")
      return
    }
  }

  func test_computeConsumerDecision_goes_to_awaitingProducer_and_resumeImmediatelyWithTerminaison_when_state_is_awaiting_existing_producer() async {
    let expectedConsumer1 = Consumer<String>.placeHolder(identifier: 0)
    let expectedConsumer2 = Consumer<String>.placeHolder(identifier: 1)

    // Given
    let stateMachineSequence = AsyncStateMachineSequence<String>()
    stateMachineSequence.state.apply(criticalState: .awaitingProducer(consumers: [expectedConsumer1, expectedConsumer2]))

    // When
    let consumerDecision = stateMachineSequence.computeConsumerDecision(
      consumerIdentifier: expectedConsumer2.identifier,
      continuation: nil
    )

    // Then
    guard
      case let .awaitingProducer(consumers) = stateMachineSequence.state.criticalState,
      consumers.count == 1,
      consumers == [expectedConsumer1] else {
      XCTFail("The state should be .awaitingProducer with one consumer")
      return
    }

    guard case .resumeImmediatelyWithTerminaison = consumerDecision else {
      XCTFail("The consumer decision should be .resumeImmediatelyWithTerminaison")
      return
    }
  }

  func test_computeConsumerDecision_goes_to_idle_and_resumeImmediatelyWithTerminaison_when_state_is_awaiting_one_producer() async {
    let expectedConsumer1 = Consumer<String>.placeHolder(identifier: 0)

    // Given
    let stateMachineSequence = AsyncStateMachineSequence<String>()
    stateMachineSequence.state.apply(criticalState: .awaitingProducer(consumers: [expectedConsumer1]))

    // When
    let consumerDecision = stateMachineSequence.computeConsumerDecision(
      consumerIdentifier: expectedConsumer1.identifier,
      continuation: nil
    )

    // Then
    guard
      case .idle = stateMachineSequence.state.criticalState else {
      XCTFail("The state should be .idle")
      return
    }

    guard case .resumeImmediatelyWithTerminaison = consumerDecision else {
      XCTFail("The consumer decision should be .resumeImmediatelyWithTerminaison")
      return
    }
  }

}
