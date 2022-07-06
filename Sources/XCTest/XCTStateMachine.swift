//
//  XCTStateMachine.swift
//
//
//  Created by Thibault WITTEMBERG on 25/06/2022.
//

#if DEBUG
import XCTestDynamicOverlay

public class XCTStateMachine<S, E, O>
where 
S: DSLCompatible & Equatable,
E: DSLCompatible & Equatable,
O: DSLCompatible & Equatable {
  let stateMachine: StateMachine<S, E, O>

  public init(_ stateMachine: StateMachine<S, E, O>) {
    self.stateMachine = stateMachine
  }

  @discardableResult
  public func assert(
    when states: S...,
    on event: E,
    transitionTo expectedState: S,
    fail: (String) -> Void = XCTFail
  ) async -> Self {
    for state in states {
      let receivedState = await self.stateMachine.reduce(when: state, on: event)
      guard receivedState == expectedState else {
        fail(
                    """
                The assertion failed for state \(state) and event \(event):
                expected new state: \(expectedState),
                received new state: \(String(describing: receivedState))
"""
        )
        return self
      }
    }
    return self
  }

  @discardableResult
  public func assertNoTransition(
    when states: S...,
    on event: E,
    fail: (String) -> Void = XCTFail
  ) async -> Self {
    for state in states {
      if let receivedState = await self.stateMachine.reduce(when: state, on: event) {
        fail(
                    """
                    The assertion failed for state \(state) and event \(event):
                    expected no new state,
                    received new state: \(receivedState)
                    """
        )
        return self
      }
    }
    return self
  }

  @discardableResult
  public func assert(
    when states: S...,
    execute expectedOutput: O,
    fail: (String) -> Void = XCTFail
  ) -> Self {
    for state in states {
      let receivedOutput = self.stateMachine.output(for: state)
      guard receivedOutput == expectedOutput else {
        fail(
                    """
                The assertion failed for state \(state):
                expected output: \(expectedOutput),
                received output: \(String(describing: receivedOutput))
"""
        )
        return self
      }
    }
    return self
  }

  @discardableResult
  public func assertNoOutput(
    when states: S...,
    fail: (String) -> Void = XCTFail
  ) -> Self {
    for state in states {
      if let receivedOutput = self.stateMachine.output(for: state) {
        fail(
                    """
                The assertion failed for state \(state):
                expected no output,
                received output: \(receivedOutput)
"""
        )
        return self
      }
    }
    return self
  }
}
#endif
