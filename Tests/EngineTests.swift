//
//  EngineTests.swift
//
//
//  Created by Thibault WITTEMBERG on 20/06/2022.
//

@testable import AsyncStateMachine
@preconcurrency import XCTest

final class EngineTests: XCTestCase {
  enum State: DSLCompatible, Equatable {
    case s1
    case s2(value: String)
    case s3
    case s4(value: Int)
  }

  enum Event: DSLCompatible, Equatable {
    case e1
    case e2(value: String)
    case e3
    case e4
  }

  enum Output: DSLCompatible, Equatable {
    case o1
    case o2
  }

  func test_init_sets_all_the_properties_when_called_with_state_machine_and_runtime() async throws {
    let outputIsCalled = ManagedCriticalState<Bool>(false)
    let transitionIsCalled = ManagedCriticalState<Bool>(false)
    let sideEffectIsCalled = ManagedCriticalState<Bool>(false)

    let stateMachine = StateMachine<State, Event, Output>(initial: State.s1) {
      When(state: State.s1) { _ in
        outputIsCalled.apply(criticalState: true)
        return Execute(output: Output.o1)
      } transitions: { _ in
        On(event: Event.e1) { _ in
          transitionIsCalled.apply(criticalState: true)
          return Transition(to: State.s2(value: "2"))
        }
      }
    }

    let runtime = Runtime<State, Event, Output>()
      .map(output: Output.o1, to: {
        sideEffectIsCalled.apply(criticalState: true)
        return Event.e1
      })
      .register(middleware: { (state: State) in })
      .register(middleware: { (event: Event) in })

    // Given
    let sut = Engine(stateMachine: stateMachine, runtime: runtime)

    // When
    let initialState = await sut.resolveInitialState()
    // Then
    XCTAssertEqual(initialState, State.s1)

    // When
    _ = await sut.resolveOutput(State.s1)
    // Then
    XCTAssertTrue(outputIsCalled.criticalState)

    // When
    _ = await sut.computeNextState(State.s1, Event.e1)
    XCTAssertTrue(transitionIsCalled.criticalState)

    // When
    let receivedSideEffect = await sut.resolveSideEffect(Output.o1)
    // Then
    let eventSequence = receivedSideEffect?.execute(Output.o1)
    let _ = try await eventSequence?.collect()
    XCTAssertTrue(sideEffectIsCalled.criticalState)

    // When
    Task {
      await sut.sendEvent(Event.e1)
    }
    // Then
    let receivedEvent = await sut.getEvent()
    XCTAssertEqual(receivedEvent, Event.e1)

    // When
    let stateMiddlewaresCount = await sut.stateMiddlewares.count
    // Then
    XCTAssertEqual(stateMiddlewaresCount, 1)

    // When
    let eventMiddlewaresCount = await sut.eventMiddlewares.count
    // Then
    XCTAssertEqual(eventMiddlewaresCount, 1)

    // When
    let tasksInProgressCount = await sut.tasksInProgress.count
    // Then
    XCTAssertEqual(tasksInProgressCount, 0)
  }

  func test_init_sets_all_the_properties_when_called_with_functions() async throws {
    let resolveInitialStateIsCalled = ManagedCriticalState<Bool>(false)
    let resolvedOutputIsCalled = ManagedCriticalState<Bool>(false)
    let computeNextStateIsCalled = ManagedCriticalState<Bool>(false)
    let resolveSideEffectIsCalled = ManagedCriticalState<Bool>(false)
    let sendEventIsCalled = ManagedCriticalState<Bool>(false)
    let getEventIsCalled = ManagedCriticalState<Bool>(false)
    let eventMiddlewareIsCalled = ManagedCriticalState<Bool>(false)
    let stateMiddlewareIsCalled = ManagedCriticalState<Bool>(false)

    let eventMiddleware = Middleware<Event>(execute: { _ in eventMiddlewareIsCalled.apply(criticalState: true); return false }, priority: nil)
    let stateMiddleware = Middleware<State>(execute: { _ in stateMiddlewareIsCalled.apply(criticalState: true); return false }, priority: nil)

    // Given
    let sut = Engine<State, Event, Output>(
      resolveInitialState: { resolveInitialStateIsCalled.apply(criticalState: true); return State.s1 },
      resolveOutput: { _ in resolvedOutputIsCalled.apply(criticalState: true); return nil },
      computeNextState: { _, _ in computeNextStateIsCalled.apply(criticalState: true); return nil},
      resolveSideEffect: { _ in resolveSideEffectIsCalled.apply(criticalState: true); return nil },
      sendEvent: { _ in sendEventIsCalled.apply(criticalState: true) },
      getEvent: { getEventIsCalled.apply(criticalState: true); return nil },
      eventMiddlewares: [eventMiddleware],
      stateMiddlewares: [stateMiddleware]
    )

    // When
    _ = await sut.resolveInitialState()
    // Then
    XCTAssertTrue(resolveInitialStateIsCalled.criticalState)

    // When
    _ = await sut.resolveOutput(State.s1)
    // Then
    XCTAssertTrue(resolvedOutputIsCalled.criticalState)

    // When
    _ = await sut.computeNextState(State.s1, Event.e1)
    XCTAssertTrue(computeNextStateIsCalled.criticalState)

    // When
    _ = await sut.resolveSideEffect(Output.o1)
    // Then
    XCTAssertTrue(resolveSideEffectIsCalled.criticalState)

    // When
    await sut.sendEvent(Event.e1)
    // Then
    XCTAssertTrue(sendEventIsCalled.criticalState)

    // When
    _ = await sut.getEvent()
    // Then
    XCTAssertTrue(getEventIsCalled.criticalState)

    // When
    let stateMiddlewaresCount = await sut.stateMiddlewares.count
    // Then
    XCTAssertEqual(stateMiddlewaresCount, 1)

    // When
    _ = await sut.stateMiddlewares.values.first?.execute(State.s1)
    // Then
    XCTAssertTrue(stateMiddlewareIsCalled.criticalState)

    // When
    let eventMiddlewaresCount = await sut.eventMiddlewares.count
    // Then
    XCTAssertEqual(eventMiddlewaresCount, 1)

    // When
    _ = await sut.eventMiddlewares.values.first?.execute(Event.e1)
    // Then
    XCTAssertTrue(eventMiddlewareIsCalled.criticalState)

    // When
    let tasksInProgressCount = await sut.tasksInProgress.count
    // Then
    XCTAssertEqual(tasksInProgressCount, 0)
  }

  func test_register_adds_a_task_in_progress_and_removes_when_finished() async {
    let taskInProgressHasBeenAdded = expectation(description: "The task has been added to the tasks in progress")

    // Given
    let sut = Engine<State, Event, Output>(
      resolveInitialState: { State.s1 },
      resolveOutput: { _ in nil },
      computeNextState: { _, _ in nil},
      resolveSideEffect: { _ in nil },
      sendEvent: { _ in },
      getEvent: { nil },
      eventMiddlewares: [],
      stateMiddlewares: []
    )

    let task = Task {
      wait(for: [taskInProgressHasBeenAdded], timeout: 10.0)
    }

    // When
    let removeTask = await sut.register(taskInProgress: task, cancelOn: { _ in true })

    // Then
    let tasksInProgressCountBefore = await sut.tasksInProgress.count
    XCTAssertEqual(tasksInProgressCountBefore, 1)

    taskInProgressHasBeenAdded.fulfill()

    await removeTask.value

    let tasksInProgressCountAfter = await sut.tasksInProgress.count
    XCTAssertEqual(tasksInProgressCountAfter, 0)
  }

  func test_register_adds_a_task_in_progress_that_can_cancel() async {
    let taskHasStarted = expectation(description: "The task has started")

    let receivedState = ManagedCriticalState<State?>(nil)

    // Given
    let sut = Engine<State, Event, Output>(
      resolveInitialState: { State.s1 },
      resolveOutput: { _ in nil },
      computeNextState: { _, _ in nil},
      resolveSideEffect: { _ in nil },
      sendEvent: { _ in },
      getEvent: { nil },
      eventMiddlewares: [],
      stateMiddlewares: []
    )

    let task = Task.forEver {
      taskHasStarted.fulfill()
    } onCancel: {
    }


    // When
    await sut.register(taskInProgress: task, cancelOn: { state in
      receivedState.apply(criticalState: state)
      return true
    })

    wait(for: [taskHasStarted], timeout: 10.0)

    // Then
    let tasksInProgress = await sut.tasksInProgress.values
    let receivedShouldCancel = tasksInProgress.first?.cancellationPredicate(State.s1)

    XCTAssertTrue(receivedShouldCancel!)
    XCTAssertEqual(receivedState.criticalState, State.s1)

    task.cancel()
  }

  func test_cancelTaskInProgress_cancels_the_expected_task_when_called() async {
    let tasksHaveStarted = expectation(description: "Tasks have started")
    tasksHaveStarted.expectedFulfillmentCount = 2

    let taskAHasBeenCancelled = expectation(description: "The task A has been cancelled")
    let taskBHasBeenCancelled = ManagedCriticalState<Bool>(false)

    // Given
    let sut = Engine<State, Event, Output>(
      resolveInitialState: { State.s1 },
      resolveOutput: { _ in nil },
      computeNextState: { _, _ in nil},
      resolveSideEffect: { _ in nil },
      sendEvent: { _ in },
      getEvent: { nil },
      eventMiddlewares: [],
      stateMiddlewares: []
    )

    let taskToCancel = Task.forEver {
      tasksHaveStarted.fulfill()
    } onCancel: {
      taskAHasBeenCancelled.fulfill()
    }

    let taskToRemain = Task.forEver {
      tasksHaveStarted.fulfill()
    } onCancel: {
      taskBHasBeenCancelled.apply(criticalState: true)
    }

    await sut.register(taskInProgress: taskToCancel, cancelOn: { state in state == .s1 })
    await sut.register(taskInProgress: taskToRemain, cancelOn: { state in state == .s3 })

    wait(for: [tasksHaveStarted], timeout: 10.0)

    // When
    await sut.cancelTasksInProgress(for: State.s1)

    wait(for: [taskAHasBeenCancelled], timeout: 0.5)
    XCTAssertFalse(taskBHasBeenCancelled.criticalState)

    let tasksInProgress = await sut.tasksInProgress.values
    XCTAssertEqual(tasksInProgress.count, 1)

    taskToRemain.cancel()
  }

  func test_cancelTasksInProgress_cancels_all_tasks_when_called() async {
    let tasksHaveBeenCancelled = expectation(description: "The tasks have been cancelled")
    tasksHaveBeenCancelled.expectedFulfillmentCount = 2

    // Given
    let sut = Engine<State, Event, Output>(
      resolveInitialState: { State.s1 },
      resolveOutput: { _ in nil },
      computeNextState: { _, _ in nil},
      resolveSideEffect: { _ in nil },
      sendEvent: { _ in },
      getEvent: { nil },
      eventMiddlewares: [],
      stateMiddlewares: []
    )

    let taskToCancelA = Task.forEver {
    } onCancel: {
      tasksHaveBeenCancelled.fulfill()
    }

    let taskToCancelB = Task.forEver {
    } onCancel: {
      tasksHaveBeenCancelled.fulfill()
    }

    await sut.register(taskInProgress: taskToCancelA, cancelOn: { state in state == .s1 })
    await sut.register(taskInProgress: taskToCancelB, cancelOn: { state in state == .s3 })

    // When
    await sut.cancelTasksInProgress()

    wait(for: [tasksHaveBeenCancelled], timeout: 10.0)

    let tasksInProgress = await sut.tasksInProgress.values
    XCTAssertTrue(tasksInProgress.isEmpty)
  }

  func test_process_executes_event_middleware_when_called() async {
    let middlewareACanFinish = expectation(description: "The middleware A can finish")
    let middlewareBCanFinish = expectation(description: "The middleware B can finish")

    let middlewaresHaveBeenCalled = expectation(description: "The middlewares have been called")
    middlewaresHaveBeenCalled.expectedFulfillmentCount = 2

    let receivedEventInMiddlewareA = ManagedCriticalState<Event?>(nil)
    let receivedEventInMiddlewareB = ManagedCriticalState<Event?>(nil)

    let receivedTaskPriorityInMiddlewareA = ManagedCriticalState<TaskPriority?>(nil)
    let receivedTaskPriorityInMiddlewareB = ManagedCriticalState<TaskPriority?>(nil)

    // Given
    let middlewareA = Middleware(execute: { (event: Event) in
      receivedEventInMiddlewareA.apply(criticalState: event)
      receivedTaskPriorityInMiddlewareA.apply(criticalState: Task.currentPriority)

      middlewaresHaveBeenCalled.fulfill()

      self.wait(for: [middlewareACanFinish], timeout: 10.0)
      return false
    }, priority: .utility)

    let middlewareB = Middleware(execute: { (event: Event) in
      receivedEventInMiddlewareB.apply(criticalState: event)
      receivedTaskPriorityInMiddlewareB.apply(criticalState: Task.currentPriority)

      middlewaresHaveBeenCalled.fulfill()

      self.wait(for: [middlewareBCanFinish], timeout: 10.0)
      return true
    }, priority: .high)

    let sut = Engine<State, Event, Output>(
      resolveInitialState: { State.s1 },
      resolveOutput: { _ in nil },
      computeNextState: { _, _ in nil},
      resolveSideEffect: { _ in nil },
      sendEvent: { _ in },
      getEvent: { nil },
      eventMiddlewares: [middlewareA, middlewareB],
      stateMiddlewares: []
    )

    // When
    let removeTasksInProgressTasks = await sut.process(event: Event.e1)

    wait(for: [middlewaresHaveBeenCalled], timeout: 10.0)

    // Then
    XCTAssertEqual(receivedEventInMiddlewareA.criticalState, Event.e1)
    XCTAssertEqual(receivedEventInMiddlewareB.criticalState, Event.e1)

    XCTAssertTrue(receivedTaskPriorityInMiddlewareA.criticalState.unsafelyUnwrapped >= .utility)
    XCTAssertTrue(receivedTaskPriorityInMiddlewareB.criticalState.unsafelyUnwrapped >= .high)

    var eventMiddlewares = await sut.eventMiddlewares.values
    XCTAssertEqual(eventMiddlewares.count, 2)

    var tasksInProgress = await sut.tasksInProgress.values
    XCTAssertEqual(tasksInProgress.count, 2)

    middlewareACanFinish.fulfill()
    middlewareBCanFinish.fulfill()

    // waiting for all tasks in progress (middlewares) to finish
    for task in removeTasksInProgressTasks {
      await task.value
    }

    eventMiddlewares = await sut.eventMiddlewares.values
    XCTAssertEqual(eventMiddlewares.count, 1)

    tasksInProgress = await sut.tasksInProgress.values
    XCTAssertTrue(tasksInProgress.isEmpty)
  }

  func test_process_registers_non_cancellable_tasks_on_specific_state_when_called() async {
    let middlewaresHaveStarted = expectation(description: "The middlewares have started")
    middlewaresHaveStarted.expectedFulfillmentCount = 2

    let middlewareAHasBeenCancelled = ManagedCriticalState<Bool>(false)
    let middlewareBHasBeenCancelled = ManagedCriticalState<Bool>(false)

    // Given
    let middlewareA = Middleware(execute: { (state: State) in
      await Task.forEver {
        middlewaresHaveStarted.fulfill()
      } onCancel: {
        middlewareAHasBeenCancelled.apply(criticalState: true)
      }.value

      return false
    }, priority: nil)

    let middlewareB = Middleware(execute: { (state: State) in
      await Task.forEver {
        middlewaresHaveStarted.fulfill()
      } onCancel: {
        middlewareBHasBeenCancelled.apply(criticalState: true)
      }.value

      return false
    }, priority: nil)

    let sut = Engine<State, Event, Output>(
      resolveInitialState: { State.s1 },
      resolveOutput: { _ in nil },
      computeNextState: { _, _ in nil},
      resolveSideEffect: { _ in nil },
      sendEvent: { _ in },
      getEvent: { nil },
      eventMiddlewares: [],
      stateMiddlewares: []
    )

    // When
    await sut.process(middlewares: [(0, middlewareA), (1, middlewareB)], using: State.s1, removeMiddleware: { _ in })

    wait(for: [middlewaresHaveStarted], timeout: 10.0)

    // Then
    var tasksInProgress = await sut.tasksInProgress.values
    XCTAssertEqual(tasksInProgress.count, 2)

    await sut.cancelTasksInProgress(for: State.s1)

    tasksInProgress = await sut.tasksInProgress.values
    XCTAssertEqual(tasksInProgress.count, 2)

    await sut.cancelTasksInProgress()

    tasksInProgress = await sut.tasksInProgress.values
    XCTAssertTrue(tasksInProgress.isEmpty)
  }

  func test_process_state_cancels_all_eligible_tasks_when_called() async {
    let tasksAreStarted = expectation(description: "All the tasks are started")
    tasksAreStarted.expectedFulfillmentCount = 3

    let tasksAreCancelled = expectation(description: "Elligible tasks are cancelled")
    tasksAreCancelled.expectedFulfillmentCount = 2

    let notElligibleTaskHasBeenCancelled = ManagedCriticalState<Bool>(false)

    // Given
    let sut = Engine<State, Event, Output>(
      resolveInitialState: { State.s1 },
      resolveOutput: { _ in nil },
      computeNextState: { _, _ in nil},
      resolveSideEffect: { _ in nil },
      sendEvent: { _ in },
      getEvent: { nil },
      eventMiddlewares: [],
      stateMiddlewares: []
    )

    let taskToCancelA = Task.forEver {
      tasksAreStarted.fulfill()
    } onCancel: {
      tasksAreCancelled.fulfill()
    }

    let taskToNotCancel = Task.forEver {
      tasksAreStarted.fulfill()
    } onCancel: {
      notElligibleTaskHasBeenCancelled.apply(criticalState: true)
    }

    let taskToCancelB = Task.forEver {
      tasksAreStarted.fulfill()
    } onCancel: {
      tasksAreCancelled.fulfill()
    }

    await sut.register(taskInProgress: taskToCancelA, cancelOn: { $0 == .s3 })
    await sut.register(taskInProgress: taskToNotCancel, cancelOn: { $0.matches(State.s2(value:)) })
    await sut.register(taskInProgress: taskToCancelB, cancelOn: { $0 == .s3 })

    wait(for: [tasksAreStarted], timeout: 10.0)

    // When
    await sut.process(state: State.s3)

    // Then
    wait(for: [tasksAreCancelled], timeout: 10.0)
    XCTAssertFalse(notElligibleTaskHasBeenCancelled.criticalState)

    let tasksInProgress = await sut.tasksInProgress.values
    XCTAssertEqual(tasksInProgress.count, 1)

    taskToNotCancel.cancel()
  }

  func test_process_state_executes_state_middleware_when_called() async {
    let middlewareACanFinish = expectation(description: "The middleware A can finish")
    let middlewareBCanFinish = expectation(description: "The middleware B can finish")

    let middlewaresHaveBeenCalled = expectation(description: "The middlewares have been called")
    middlewaresHaveBeenCalled.expectedFulfillmentCount = 2

    let receivedStateInMiddlewareA = ManagedCriticalState<State?>(nil)
    let receivedStateInMiddlewareB = ManagedCriticalState<State?>(nil)

    let receivedTaskPriorityInMiddlewareA = ManagedCriticalState<TaskPriority?>(nil)
    let receivedTaskPriorityInMiddlewareB = ManagedCriticalState<TaskPriority?>(nil)

    // Given
    let middlewareA = Middleware(execute: { (state: State) in
      receivedStateInMiddlewareA.apply(criticalState: state)
      receivedTaskPriorityInMiddlewareA.apply(criticalState: Task.currentPriority)

      middlewaresHaveBeenCalled.fulfill()

      self.wait(for: [middlewareACanFinish], timeout: 10.0)
      return false
    }, priority: .utility)

    let middlewareB = Middleware(execute: { (state: State) in
      receivedStateInMiddlewareB.apply(criticalState: state)
      receivedTaskPriorityInMiddlewareB.apply(criticalState: Task.currentPriority)

      middlewaresHaveBeenCalled.fulfill()

      self.wait(for: [middlewareBCanFinish], timeout: 10.0)
      return true
    }, priority: .high)

    let sut = Engine<State, Event, Output>(
      resolveInitialState: { State.s1 },
      resolveOutput: { _ in nil },
      computeNextState: { _, _ in nil},
      resolveSideEffect: { _ in nil },
      sendEvent: { _ in },
      getEvent: { nil },
      eventMiddlewares: [],
      stateMiddlewares: [middlewareA, middlewareB]
    )

    // When
    let removeTasksInProgressTasks = await sut.process(state: State.s1)

    wait(for: [middlewaresHaveBeenCalled], timeout: 10.0)

    // Then
    XCTAssertEqual(receivedStateInMiddlewareA.criticalState, State.s1)
    XCTAssertEqual(receivedStateInMiddlewareB.criticalState, State.s1)

    XCTAssertTrue(receivedTaskPriorityInMiddlewareA.criticalState.unsafelyUnwrapped >= .utility)
    XCTAssertTrue(receivedTaskPriorityInMiddlewareB.criticalState.unsafelyUnwrapped >= .high)

    var stateMiddlewares = await sut.stateMiddlewares.values
    XCTAssertEqual(stateMiddlewares.count, 2)

    var tasksInProgress = await sut.tasksInProgress.values
    XCTAssertEqual(tasksInProgress.count, 2)

    middlewareACanFinish.fulfill()
    middlewareBCanFinish.fulfill()

    // waiting for all tasks in progress (middlewares) to finish
    for task in removeTasksInProgressTasks {
      await task.value
    }

    stateMiddlewares = await sut.stateMiddlewares.values
    XCTAssertEqual(stateMiddlewares.count, 1)

    tasksInProgress = await sut.tasksInProgress.values
    XCTAssertTrue(tasksInProgress.isEmpty)
  }

  func test_process_state_execute_side_effects_when_called() async {
    let sideEffectIsCalled = expectation(description: "Side effect is called")

    let resolveSideEffectIsCalled = ManagedCriticalState<Bool>(false)

    // Given
    let sut = Engine<State, Event, Output>(
      resolveInitialState: { State.s1 },
      resolveOutput: { _ in Output.o1 },
      computeNextState: { _, _ in nil},
      resolveSideEffect: { _ in
        resolveSideEffectIsCalled.apply(criticalState: true)
        return SideEffect(
          predicate: { _ in true},
          execute: { _ in
            AsyncJustSequence {
              sideEffectIsCalled.fulfill()
              return Event.e1
            }.eraseToAnyAsyncSequence()
          },
          priority: nil,
          strategy: .continueWhenAnyState
        )
      },
      sendEvent: { _ in },
      getEvent: { nil },
      eventMiddlewares: [],
      stateMiddlewares: []
    )

    // When
    await sut.process(state: State.s1)

    // Then
    wait(for: [sideEffectIsCalled], timeout: 10.0)

    XCTAssertTrue(resolveSideEffectIsCalled.criticalState)
  }

  func test_executeSideEffect_execute_side_effect_when_called() async {
    let eventIsSent = expectation(description: "Event from side effect is sent")

    let receivedStateInResolveOutput = ManagedCriticalState<State?>(nil)
    let receivedOutputInResolveSideEffect = ManagedCriticalState<Output?>(nil)
    let receivedOutputInExecute = ManagedCriticalState<Output?>(nil)
    let receivedEventInSendEvent = ManagedCriticalState<Event?>(nil)
    let receivedPriority = ManagedCriticalState<TaskPriority?>(nil)

    // Given
    let sut = Engine<State, Event, Output>(
      resolveInitialState: { State.s1 },
      resolveOutput: { state in
        receivedStateInResolveOutput.apply(criticalState: state)
        return Output.o1
      },
      computeNextState: { _, _ in nil},
      resolveSideEffect: { output in
        receivedOutputInResolveSideEffect.apply(criticalState: output)
        return SideEffect(
          predicate: { _ in true },
          execute: { output in
            receivedOutputInExecute.apply(criticalState: output)
            return AsyncJustSequence {
              receivedPriority.apply(criticalState: Task.currentPriority)
              return Event.e1
            }.eraseToAnyAsyncSequence()
          },
          priority: .high,
          strategy: .continueWhenAnyState
        )
      },
      sendEvent: { event in
        receivedEventInSendEvent.apply(criticalState: event)
        eventIsSent.fulfill()
      },
      getEvent: { nil },
      eventMiddlewares: [],
      stateMiddlewares: []
    )

    // When
    let cleaningTask = await sut.executeSideEffect(for: State.s3)

    wait(for: [eventIsSent], timeout: 10.0)

    // Then
    XCTAssertEqual(receivedStateInResolveOutput.criticalState, .s3)
    XCTAssertEqual(receivedOutputInResolveSideEffect.criticalState, .o1)
    XCTAssertEqual(receivedOutputInExecute.criticalState, .o1)
    XCTAssertEqual(receivedEventInSendEvent.criticalState, .e1)
    XCTAssertTrue(receivedPriority.criticalState.unsafelyUnwrapped >= .high)

    await cleaningTask?.value

    let tasksInProgress = await sut.tasksInProgress.values
    XCTAssertTrue(tasksInProgress.isEmpty)
  }

  func test_executeSideEffect_execute_side_effect_when_side_effect_fails() async {
    // Given
    let sut = Engine<State, Event, Output>(
      resolveInitialState: { State.s1 },
      resolveOutput: { _ in Output.o1 },
      computeNextState: { _, _ in nil},
      resolveSideEffect: { _ in
        return SideEffect(
          predicate: { _ in true },
          execute: { _ in AsyncThrowingSequence<Event>().eraseToAnyAsyncSequence() },
          priority: nil,
          strategy: .continueWhenAnyState
        )
      },
      sendEvent: { _ in },
      getEvent: { nil },
      eventMiddlewares: [],
      stateMiddlewares: []
    )

    // When
    let cleaningTask = await sut.executeSideEffect(for: State.s3)

    // Then
    await cleaningTask?.value

    let tasksInProgress = await sut.tasksInProgress.values
    XCTAssertTrue(tasksInProgress.isEmpty)
  }

  func test_register_adds_onTheFly_state_middleware() async {
    let receivedState = ManagedCriticalState<State?>(nil)

    // Given
    let sut = Engine<State, Event, Output>(
      resolveInitialState: { State.s1 },
      resolveOutput: { _ in Output.o1 },
      computeNextState: { _, _ in nil},
      resolveSideEffect: { _ in nil },
      sendEvent: { _ in },
      getEvent: { nil },
      eventMiddlewares: [],
      stateMiddlewares: []
    )

    // When
    await sut.register { state in
      receivedState.apply(criticalState: state)
      return false
    }

    // Then
    let stateMiddlewares = await sut.stateMiddlewares
    XCTAssertEqual(stateMiddlewares.count, 1)

    let shouldBeRemoved = await stateMiddlewares.values.first?.execute(State.s2(value: "value"))

    XCTAssertFalse(shouldBeRemoved.unsafelyUnwrapped)
    XCTAssertEqual(receivedState.criticalState, State.s2(value: "value"))
  }
}
