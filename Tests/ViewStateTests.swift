//
//  BindingsTests.swift
//
//
//  Created by Thibault WITTEMBERG on 20/06/2022.
//

#if canImport(SwiftUI)
@testable import AsyncStateMachine
@preconcurrency import XCTest

@MainActor
final class ViewStateTests: XCTestCase {
  enum State: DSLCompatible, Equatable {
    case s1
    case s2
    case s3
    case s4(value: String)

    var value: String? {
      switch self {
      case let .s4(value): return value
      default: return nil
      }
    }
  }

  enum Event: DSLCompatible, Equatable {
    case e1
    case e2
  }

  enum Output: DSLCompatible, Equatable {
    case o1
  }

  func test_send_pushes_event_in_state_machine_when_called() async {
    let eventWasReceived = expectation(description: "Event was received")
    let receivedEvent = ManagedCriticalState<Event?>(nil)
    let expectedEvent = Event.e1

    // Given
    let stateMachine = StateMachine<State, Event, Never>(initial: State.s1) {}
    let runtime = Runtime<State, Event, Never>()
      .register(middleware: { (event: Event) in
        receivedEvent.apply(criticalState: event)
        eventWasReceived.fulfill()
      })

    let sequence = AsyncStateMachineSequence(stateMachine: stateMachine, runtime: runtime)
    let sut = ViewState(asyncStateMachineSequence: sequence)

    Task {
      await sut.start()
    }

    // When
    await sut.send(expectedEvent)

    // Then
    wait(for: [eventWasReceived], timeout: 1.0)
    XCTAssertEqual(receivedEvent.criticalState, expectedEvent)
  }

  func test_send_pushes_event_in_state_machine_and_resumes_when_predicate_is_true() async {
    let expectedEvent = Event.e1

    // Given
    let stateMachine = StateMachine<State, Event, Output>(initial: State.s1) {
      When(state: .s1) { _ in
        Execute.noOutput
      } transitions: { _ in
        On(event: .e1) { _ in
          Transition(to: .s2)
        }
      }

      When(state: .s2) { _ in
        Execute(output: .o1)
      } transitions: { _ in
        On(event: .e2) { _ in
          Transition(to: .s3)
        }
      }
    }
    let runtime = Runtime<State, Event, Output>()
      .map(output: .o1, to: { Event.e2 })

    let sequence = AsyncStateMachineSequence(stateMachine: stateMachine, runtime: runtime)
    let sut = ViewState(asyncStateMachineSequence: sequence)

    Task {
      await sut.start()
    }

    // When
    await sut.send(expectedEvent, resumeWhen: { $0 == .s3 })

    // Then
  }

  func test_send_pushes_event_in_state_machine_and_resumes_when_state_is_reached() async {
    let expectedEvent = Event.e1

    // Given
    let stateMachine = StateMachine<State, Event, Output>(initial: State.s1) {
      When(state: .s1) { _ in
        Execute.noOutput
      } transitions: { _ in
        On(event: .e1) { _ in
          Transition(to: .s2)
        }
      }

      When(state: .s2) { _ in
        Execute(output: .o1)
      } transitions: { _ in
        On(event: .e2) { _ in
          Transition(to: .s3)
        }
      }
    }
    let runtime = Runtime<State, Event, Output>()
      .map(output: .o1, to: { Event.e2 })

    let sequence = AsyncStateMachineSequence(stateMachine: stateMachine, runtime: runtime)
    let sut = ViewState(asyncStateMachineSequence: sequence)

    Task {
      await sut.start()
    }

    // When
    await sut.send(expectedEvent, resumeWhen: .s3)

    // Then
  }

  func test_send_pushes_event_in_state_machine_and_resumes_when_state_with_associated_value_is_reached() async {
    let expectedEvent = Event.e1

    // Given
    let stateMachine = StateMachine<State, Event, Output>(initial: State.s1) {
      When(state: .s1) { _ in
        Execute.noOutput
      } transitions: { _ in
        On(event: .e1) { _ in
          Transition(to: .s2)
        }
      }

      When(state: .s2) { _ in
        Execute(output: .o1)
      } transitions: { _ in
        On(event: .e2) { _ in
          Transition(to: State.s4(value: "value"))
        }
      }
    }
    let runtime = Runtime<State, Event, Output>()
      .map(output: .o1, to: { Event.e2 })

    let sequence = AsyncStateMachineSequence(stateMachine: stateMachine, runtime: runtime)
    let sut = ViewState(asyncStateMachineSequence: sequence)

    Task {
      await sut.start()
    }

    // When
    await sut.send(expectedEvent, resumeWhen: State.s4(value:))

    // Then
  }

  func test_send_pushes_event_in_state_machine_and_resumes_when_state_is_oneOf() async {
    let expectedEvent = Event.e1

    // Given
    let stateMachine = StateMachine<State, Event, Output>(initial: State.s1) {
      When(state: .s1) { _ in
        Execute.noOutput
      } transitions: { _ in
        On(event: .e1) { _ in
          Transition(to: .s2)
        }
      }

      When(state: .s2) { _ in
        Execute(output: .o1)
      } transitions: { _ in
        On(event: .e2) { _ in
          Transition(to: State.s4(value: "value"))
        }
      }
    }
    let runtime = Runtime<State, Event, Output>()
      .map(output: .o1, to: { Event.e2 })

    let sequence = AsyncStateMachineSequence(stateMachine: stateMachine, runtime: runtime)
    let sut = ViewState(asyncStateMachineSequence: sequence)

    Task {
      await sut.start()
    }

    // When
    await sut.send(expectedEvent, resumeWhen: OneOf {
      State.s3
      State.s4(value:)
    })

    // Then
  }

  func test_binding_returns_binding_that_sends_event_when_passing_event() {
    let eventWasReceived = expectation(description: "Event was received")
    let receivedEvent = ManagedCriticalState<Event?>(nil)
    let expectedEvent = Event.e1

    let stateMachine = StateMachine<State, Event, Never>(initial: State.s1) {}
    let runtime = Runtime<State, Event, Never>()
      .register(middleware: { (event: Event) in
        receivedEvent.apply(criticalState: event)
        eventWasReceived.fulfill()
      })

    let sequence = AsyncStateMachineSequence(stateMachine: stateMachine, runtime: runtime)
    let sut = ViewState(asyncStateMachineSequence: sequence)

    Task {
      await sut.start()
    }

    // Given
    let received = sut.binding(send: expectedEvent)

    XCTAssertEqual(received.wrappedValue, State.s1)

    // When
    received.wrappedValue = .s2

    wait(for: [eventWasReceived], timeout: 1.0)

    // Then
    XCTAssertEqual(receivedEvent.criticalState, expectedEvent)
  }

  func test_binding_returns_binding_that_receives_state_and_sends_event_when_passing_event_closure() {
    let eventWasReceived = expectation(description: "Event was received")
    var receivedState: State?
    let expectedState = State.s2
    let receivedEvent = ManagedCriticalState<Event?>(nil)
    let expectedEvent = Event.e1

    let stateMachine = StateMachine<State, Event, Never>(initial: State.s1) {}
    let runtime = Runtime<State, Event, Never>()
      .register(middleware: { (event: Event) in
        receivedEvent.apply(criticalState: event)
        eventWasReceived.fulfill()
      })

    let sequence = AsyncStateMachineSequence(stateMachine: stateMachine, runtime: runtime)
    let sut = ViewState(asyncStateMachineSequence: sequence)

    Task {
      await sut.start()
    }

    // Given
    let received = sut.binding(send: { state in
      receivedState = state
      return expectedEvent
    })

    XCTAssertEqual(received.wrappedValue, State.s1)

    // When
    received.wrappedValue = .s2

    wait(for: [eventWasReceived], timeout: 1.0)

    // Then
    XCTAssertEqual(receivedState, expectedState)
    XCTAssertEqual(receivedEvent.criticalState, expectedEvent)
  }

  func test_binding_returns_binding_that_receives_value_and_sends_event_when_passing_keypath_and_event_closure() {
    let eventWasReceived = expectation(description: "Event was received")
    let receivedValue = ManagedCriticalState<String?>(nil)
    let expectedValue = "value"

    let receivedEvent = ManagedCriticalState<Event?>(nil)
    let expectedEvent = Event.e1

    let stateMachine = StateMachine<State, Event, Never>(initial: State.s1) {}
    let runtime = Runtime<State, Event, Never>()
      .register(middleware: { (event: Event) in
        receivedEvent.apply(criticalState: event)
        eventWasReceived.fulfill()
      })

    let sequence = AsyncStateMachineSequence(stateMachine: stateMachine, runtime: runtime)
    let sut = ViewState(asyncStateMachineSequence: sequence)

    Task {
      await sut.start()
    }

    // Given
    let received = sut.binding(keypath: \.value) { value in
      receivedValue.apply(criticalState: value)
      return expectedEvent
    }

    // initial state is State.s1 (\.value is nil)
    XCTAssertNil(received.wrappedValue)
    
    sut.state = State.s4(value: expectedValue)
    XCTAssertEqual(received.wrappedValue, expectedValue)

    // When
    received.wrappedValue = expectedValue

    wait(for: [eventWasReceived], timeout: 1.0)

    // Then
    XCTAssertEqual(receivedValue.criticalState, expectedValue)
    XCTAssertEqual(receivedEvent.criticalState, expectedEvent)
  }

  func test_binding_returns_binding_that_receives_value_and_sends_event_when_passing_keypath_and_event() {
    let eventWasReceived = expectation(description: "Event was received")
    let expectedValue = "value"

    let receivedEvent = ManagedCriticalState<Event?>(nil)
    let expectedEvent = Event.e1

    let stateMachine = StateMachine<State, Event, Never>(initial: State.s1) {}
    let runtime = Runtime<State, Event, Never>()
      .register(middleware: { (event: Event) in
        receivedEvent.apply(criticalState: event)
        eventWasReceived.fulfill()
      })

    let sequence = AsyncStateMachineSequence(stateMachine: stateMachine, runtime: runtime)
    let sut = ViewState(asyncStateMachineSequence: sequence)

    Task {
      await sut.start()
    }

    // Given
    let received = sut.binding(keypath: \.value, send: expectedEvent)

    // initial state is State.s1 (\.value is nil)
    XCTAssertNil(received.wrappedValue)

    sut.state = State.s4(value: expectedValue)
    XCTAssertEqual(received.wrappedValue, expectedValue)

    // When
    received.wrappedValue = expectedValue

    wait(for: [eventWasReceived], timeout: 1.0)

    // Then
    XCTAssertEqual(receivedEvent.criticalState, expectedEvent)
  }
}
#endif
