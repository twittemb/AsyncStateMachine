//
//  AsyncJustSequenceTests.swift
//  
//
//  Created by Thibault WITTEMBERG on 02/07/2022.
//

@testable import AsyncStateMachine
@preconcurrency import XCTest

final class AsyncJustSequenceTests: XCTestCase {
  func test_init_sets_element() async {
    let element = Int.random(in: 0...100)
    let sut = AsyncJustSequence { element }
    let value = await sut.element()
    XCTAssertEqual(value, element)
  }

  func test_just_outputs_expected_element_and_finishes() async {
    var receivedResult = [Int]()

    let element = Int.random(in: 0...100)
    let sut = AsyncJustSequence { element }

    for await result in sut {
      receivedResult.append(result)
    }

    XCTAssertEqual(receivedResult, [element])
  }

  func test_just_returns_an_asyncSequence_that_finishes_without_elements_when_task_is_cancelled() {
    let hasCancelledExpectation = expectation(description: "The task has been cancelled")
    let hasFinishedExpectation = expectation(description: "The AsyncSequence has finished")

    let sut = AsyncJustSequence { 1 }

    let task = Task {
      wait(for: [hasCancelledExpectation], timeout: 1)
      for await _ in sut {
        XCTFail("The AsyncSequence should not output elements")
      }
      hasFinishedExpectation.fulfill()
    }

    task.cancel()

    hasCancelledExpectation.fulfill()

    wait(for: [hasFinishedExpectation], timeout: 1)
  }
}
