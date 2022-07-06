//
//  XCTStateMachineTests.swift
//
//
//  Created by Thibault WITTEMBERG on 20/06/2022.
//

@testable import AsyncStateMachine
import XCTest

final class XCTStateMachineTests: XCTestCase {
  enum State: DSLCompatible, Equatable {
    case s1
    case s2(value: String)
  }

  enum Event: DSLCompatible, Equatable {
    case e1
    case e2(value: String)
  }

  enum Output: DSLCompatible, Equatable {
    case o1
  }

  func test_assertNoOutput_succeeds_when_no_output() {
    // Given
    let stateMachine = StateMachine<State, Event, Output>(initial: State.s1) {
      When(state: State.s1) { _ in
        Execute.noOutput
      } transitions: { _ in
      }

      When(state: State.s2(value:)) { _ in
        Execute.noOutput
      } transitions: { _ in
      }
    }

    // When
    // Then
    XCTStateMachine(stateMachine).assertNoOutput(when: State.s1, State.s2(value: "value"))
  }

  func test_assertNoOutput_fails_when_output() {
    var failIsCalled = false

    // Given
    let stateMachine = StateMachine<State, Event, Output>(initial: State.s1) {
      When(state: State.s1) { _ in
        Execute.noOutput
      } transitions: { _ in
      }

      When(state: State.s2(value:)) { _ in
        Execute(output: .o1)
      } transitions: { _ in
      }
    }

    // When
    XCTStateMachine(stateMachine)
      .assertNoOutput(when: State.s1, State.s2(value: "value"), fail: { _ in failIsCalled = true })

    // Then
    XCTAssertTrue(failIsCalled)
  }
}
