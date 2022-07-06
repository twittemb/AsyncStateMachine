//
//  AsyncJustSequenceTests.swift
//
//
//  Created by Thibault WITTEMBERG on 02/07/2022.
//

@preconcurrency import XCTest
@testable import AsyncStateMachine

final class TestChannel: XCTestCase {
  func test_asyncChannel_delivers_values_when_two_producers_and_two_consumers() async {
    let (sentFromProducer1, sentFromProducer2) = ("test1", "test2")
    let expected = Set([sentFromProducer1, sentFromProducer2])

    let channel = AsyncChannel<String>()
    Task {
      await channel.send(sentFromProducer1)
    }
    Task {
      await channel.send(sentFromProducer2)
    }

    let t: Task<String?, Never> = Task {
      var iterator = channel.makeAsyncIterator()
      let value = await iterator.next()
      return value
    }
    var iterator = channel.makeAsyncIterator()

    let (collectedFromConsumer1, collectedFromConsumer2) = (await t.value, await iterator.next())
    let collected = Set([collectedFromConsumer1, collectedFromConsumer2])

    XCTAssertEqual(collected, expected)
  }

  func test_asyncChannel_ends_alls_iterators_and_discards_additional_sent_values_when_finish_is_called() async {
    let channel = AsyncChannel<String>()
    let complete = ManagedCriticalState(false)
    let finished = expectation(description: "finished")

    Task {
      channel.finish()
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
      var iterator = channel.makeAsyncIterator()
      let ending = await iterator.next()
      valueFromConsumer1.withCriticalRegion { $0 = ending }
      received.fulfill()
      let item = await iterator.next()
      XCTAssertNil(item)
      pastEnd.fulfill()
    }

    Task {
      var iterator = channel.makeAsyncIterator()
      let ending = await iterator.next()
      valueFromConsumer2.withCriticalRegion { $0 = ending }
      received.fulfill()
      let item = await iterator.next()
      XCTAssertNil(item)
      pastEnd.fulfill()
    }

    wait(for: [finished, received], timeout: 1.0)

    XCTAssertTrue(complete.withCriticalRegion { $0 })
    XCTAssertEqual(valueFromConsumer1.withCriticalRegion { $0 }, nil)
    XCTAssertEqual(valueFromConsumer2.withCriticalRegion { $0 }, nil)

    wait(for: [pastEnd], timeout: 1.0)
    let additionalSend = expectation(description: "additional send")
    Task {
      await channel.send("test")
      additionalSend.fulfill()
    }
    wait(for: [additionalSend], timeout: 1.0)
  }

  func test_asyncChannel_ends_iterator_when_task_is_cancelled() async {
    let channel = AsyncChannel<String>()
    let ready = expectation(description: "ready")
    let task: Task<String?, Never> = Task {
      var iterator = channel.makeAsyncIterator()
      ready.fulfill()
      return await iterator.next()
    }
    wait(for: [ready], timeout: 1.0)
    task.cancel()
    let value = await task.value
    XCTAssertNil(value)
  }

  func test_asyncChannel_resumes_send_when_task_is_cancelled() async {
    let channel = AsyncChannel<Int>()
    let notYetDone = expectation(description: "not yet done")
    notYetDone.isInverted = true
    let done = expectation(description: "done")
    let task = Task {
      await channel.send(1)
      notYetDone.fulfill()
      done.fulfill()
    }
    wait(for: [notYetDone], timeout: 0.1)
    task.cancel()
    wait(for: [done], timeout: 1.0)
  }
}
