//
//  RuntimeTests.swift
//
//
//  Created by Thibault WITTEMBERG on 20/06/2022.
//

@testable import AsyncStateMachine
@preconcurrency import XCTest

final class RuntimeTests: XCTestCase {
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
    case o2(value: String)
    case o3(value: Int)
  }

  func test_map_registers_side_effect_when_called_with_side_effect_that_returns_async_sequence() async throws {
    // Given
    let sut = Runtime<State, Event, Output>()
      .map(
        output: .o1,
        to: { AsyncJustSequence { Event.e1 } },
        priority: .userInitiated,
        strategy: .continueWhenAnyState
      )

    // When
    let sideEffect = sut.sideEffects.first!

    // Then
    XCTAssertEqual(sut.sideEffects.count, 1)
    XCTAssertTrue(sideEffect.predicate(Output.o1))
    XCTAssertFalse(sideEffect.predicate(Output.o2(value: "")))
    let sequence = sideEffect.execute(Output.o1)!
    let receivedEvents = try await sequence.collect()
    XCTAssertEqual(receivedEvents, [.e1])
    XCTAssertEqual(sideEffect.priority, .userInitiated)
    XCTAssertEqual(sideEffect.strategy, .continueWhenAnyState)
  }

  func test_map_registers_side_effect_when_called_with_side_effect_that_returns_event() async throws {
    // Given
    let sut = Runtime<State, Event, Output>()
      .map(
        output: .o1,
        to: { Event.e1 },
        priority: .userInitiated,
        strategy: .continueWhenAnyState
      )

    // When
    let sideEffect = sut.sideEffects.first!

    // Then
    XCTAssertEqual(sut.sideEffects.count, 1)
    XCTAssertTrue(sideEffect.predicate(Output.o1))
    XCTAssertFalse(sideEffect.predicate(Output.o2(value: "")))
    let sequence = sideEffect.execute(Output.o1)!
    let receivedEvents = try await sequence.collect()
    XCTAssertEqual(receivedEvents, [.e1])
    XCTAssertEqual(sideEffect.priority, .userInitiated)
    XCTAssertEqual(sideEffect.strategy, .continueWhenAnyState)
  }

  func test_map_registers_side_effect_when_called_with_side_effect_that_returns_async_sequence_and_output_with_associated_type() async throws {
    let receivedValue = ManagedCriticalState<String?>(nil)

    // Given
    let sut = Runtime<State, Event, Output>()
      .map(
        output: Output.o2(value:),
        to: { value -> AsyncJustSequence<Event> in
          receivedValue.apply(criticalState: value)
          return AsyncJustSequence { Event.e1 }
        },
        priority: .userInitiated,
        strategy: .continueWhenAnyState
      )

    // When
    let sideEffect = sut.sideEffects.first!

    // Then
    XCTAssertEqual(sut.sideEffects.count, 1)
    XCTAssertFalse(sideEffect.predicate(Output.o1))
    XCTAssertTrue(sideEffect.predicate(Output.o2(value: "value")))
    let sequence = sideEffect.execute(Output.o2(value: "value"))!
    let receivedEvents = try await sequence.collect()
    XCTAssertEqual(receivedEvents, [.e1])
    XCTAssertEqual(receivedValue.criticalState, "value")
    XCTAssertEqual(sideEffect.priority, .userInitiated)
    XCTAssertEqual(sideEffect.strategy, .continueWhenAnyState)
  }

  func test_map_registers_side_effect_when_called_with_side_effect_that_returns_event_and_output_with_associated_type() async throws {
    let receivedValue = ManagedCriticalState<String?>(nil)

    // Given
    let sut = Runtime<State, Event, Output>()
      .map(
        output: Output.o2(value:),
        to: { value in
          receivedValue.apply(criticalState: value)
          return Event.e1
        },
        priority: .userInitiated,
        strategy: .continueWhenAnyState
      )

    // When
    let sideEffect = sut.sideEffects.first!

    // Then
    XCTAssertEqual(sut.sideEffects.count, 1)
    XCTAssertFalse(sideEffect.predicate(Output.o1))
    XCTAssertTrue(sideEffect.predicate(Output.o2(value: "value")))
    let sequence = sideEffect.execute(Output.o2(value: "value"))!
    let receivedEvents = try await sequence.collect()
    XCTAssertEqual(receivedEvents, [.e1])
    XCTAssertEqual(receivedValue.criticalState, "value")
    XCTAssertEqual(sideEffect.priority, .userInitiated)
    XCTAssertEqual(sideEffect.strategy, .continueWhenAnyState)
  }

  func test_map_registers_side_effect_with_nil_async_sequence_when_output_associated_type_does_not_match() async throws {
    // Given
    let sut = Runtime<State, Event, Output>()
      .map(
        output: Output.o2(value:),
        to: { _ in Event.e1 },
        priority: .userInitiated,
        strategy: .continueWhenAnyState
      )

    // When
    let sideEffect = sut.sideEffects.first!

    // Then
    let sequence = sideEffect.execute(Output.o3(value: 3))
    XCTAssertNil(sequence)
  }

  func test_register_adds_middleware_for_state_when_called() async {
    let receivedState = ManagedCriticalState<State?>(nil)

    // Given
    let sut = Runtime<State, Event, Output>()
      .register(
        middleware: { receivedState.apply(criticalState: $0) },
        priority: .userInitiated
      )

    // When
    let middleware = sut.stateMiddlewares.first!

    // Then
    let shouldRemoveAfterExecution = await middleware.execute(State.s2(value: "value"))
    XCTAssertEqual(receivedState.criticalState, State.s2(value: "value"))
    XCTAssertFalse(shouldRemoveAfterExecution)
    XCTAssertEqual(middleware.priority, .userInitiated)
  }

  func test_register_adds_middleware_for_event_when_called() async {
    let receivedEvent = ManagedCriticalState<Event?>(nil)

    // Given
    let sut = Runtime<State, Event, Output>()
      .register(
        middleware: { receivedEvent.apply(criticalState: $0) },
        priority: .userInitiated
      )

    // When
    let middleware = sut.eventMiddlewares.first!

    // Then
    let shouldRemoveAfterExecution = await middleware.execute(Event.e2(value: "value"))
    XCTAssertEqual(receivedEvent.criticalState, Event.e2(value: "value"))
    XCTAssertFalse(shouldRemoveAfterExecution)
    XCTAssertEqual(middleware.priority, .userInitiated)
  }

  func test_connectAsReceiver_registers_channel_as_event_sender_when_called() async {
    let eventIsReceivedExpectation = expectation(description: "event has been received in middleware")
    let receivedEvent = ManagedCriticalState<Event?>(nil)

    let pipe = AsyncStateMachine.Pipe<Event>()

    // Given
    let sut = Runtime<State, Event, Output>()
      .connectAsReceiver(to: pipe)

    Task {
      for await event in sut.eventChannel {
        receivedEvent.apply(criticalState: event)
        eventIsReceivedExpectation.fulfill()
        break
      }
    }

    // When
    await pipe.push(Event.e2(value: "value"))
    wait(for: [eventIsReceivedExpectation], timeout: 1)

    // Then
    XCTAssertEqual(receivedEvent.criticalState, Event.e2(value: "value"))
  }

  func test_connectAsSender_registers_state_middleware_that_pushes_to_pipe_when_called() async {
    let receivedEvent = ManagedCriticalState<Event?>(nil)

    let pipe = AsyncStateMachine.Pipe<Event>()
    pipe.register { event in
      receivedEvent.apply(criticalState: event)
    }

    // Given
    let sut = Runtime<State, Event, Output>()
      .connectAsSender(to: pipe, when: State.s1, send: Event.e1)

    let middleware = sut.stateMiddlewares.first!

    // When
    _ = await middleware.execute(State.s2(value: ""))

    // Then
    XCTAssertNil(receivedEvent.criticalState)

    // When
    _ = await middleware.execute(State.s1)

    // Then
    XCTAssertEqual(receivedEvent.criticalState, Event.e1)
  }

  func test_connectAsSender_registers_state_middleware_that_pushes_to_pipe_when_called_with_associated_value() async {
    let receivedEvent = ManagedCriticalState<Event?>(nil)
    let receivedValue = ManagedCriticalState<String?>(nil)

    let pipe = AsyncStateMachine.Pipe<Event>()
    pipe.register { event in
      receivedEvent.apply(criticalState: event)
    }

    // Given
    let sut = Runtime<State, Event, Output>()
      .connectAsSender(to: pipe, when: State.s2(value:)) { value in
        receivedValue.apply(criticalState: value)
        return Event.e1
      }

    let middleware = sut.stateMiddlewares.first!

    // When
    _ = await middleware.execute(State.s1)

    // Then
    XCTAssertNil(receivedEvent.criticalState)
    XCTAssertNil(receivedValue.criticalState)

    // When
    _ = await middleware.execute(State.s2(value: "value"))

    // Then
    XCTAssertEqual(receivedEvent.criticalState, Event.e1)
    XCTAssertEqual(receivedValue.criticalState, "value")
  }

  func test_sideEffectForOutput_returns_side_effect_when_mapping_exists() async throws {
    // Given
    let sut = Runtime<State, Event, Output>()
      .map(
        output: .o1,
        to: { Event.e1 }
      )

    // When
    let receivedSideEffectWhenNoMapping = sut.sideEffects(for: Output.o2(value: ""))

    // Then
    XCTAssertNil(receivedSideEffectWhenNoMapping)

    // When
    let receivedSideEffectWhenMapping = sut.sideEffects(for: Output.o1)

    // Then
    let asyncSequence = receivedSideEffectWhenMapping?.execute(Output.o1)
    let receivedEvent = try await asyncSequence?.collect()
    XCTAssertEqual(receivedEvent?.first, Event.e1)
  }
}
