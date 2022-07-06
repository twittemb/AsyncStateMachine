//
//  Engine.swift
//  
//
//  Created by Thibault WITTEMBERG on 25/06/2022.
//

struct TaskInProgress<S> {
  let cancellationPredicate: (S) -> Bool
  let task: Task<Void, Never>
}

actor Engine<S, E, O>: Sendable
where S: DSLCompatible, E: DSLCompatible & Sendable, O: DSLCompatible {
  let resolveInitialState: @Sendable () -> S
  let resolveOutput: @Sendable (S) -> O?
  let computeNextState: @Sendable (S, E) async -> S?
  let resolveSideEffect: @Sendable (O) -> SideEffect<S, E, O>?

  let sendEvent: (E) async -> Void
  let getEvent: () async -> E?

  var eventMiddlewares: OrderedStorage<Middleware<E>>
  var stateMiddlewares: OrderedStorage<Middleware<S>>
  var tasksInProgress: OrderedStorage<TaskInProgress<S>>

  init(
    resolveInitialState: @Sendable @escaping () -> S,
    resolveOutput: @Sendable  @escaping (S) -> O?,
    computeNextState: @Sendable  @escaping (S, E) async -> S?,
    resolveSideEffect: @Sendable  @escaping (O) -> SideEffect<S, E, O>?,
    sendEvent: @escaping (E) async -> Void,
    getEvent: @escaping () async -> E?,
    eventMiddlewares: [Middleware<E>],
    stateMiddlewares: [Middleware<S>]
  ) {
    self.resolveInitialState = resolveInitialState
    self.resolveOutput = resolveOutput
    self.computeNextState = computeNextState
    self.resolveSideEffect = resolveSideEffect
    self.sendEvent = sendEvent
    self.getEvent = getEvent
    self.stateMiddlewares = OrderedStorage(contentOf: stateMiddlewares)
    self.eventMiddlewares = OrderedStorage(contentOf: eventMiddlewares)
    self.tasksInProgress = OrderedStorage()
  }

  convenience init(
    stateMachine: StateMachine<S, E, O>,
    runtime: Runtime<S, E, O>
  ) {
    var eventIterator = runtime.eventChannel.makeAsyncIterator()

    self.init(
      resolveInitialState: { stateMachine.initial },
      resolveOutput: stateMachine.output(for:),
      computeNextState: stateMachine.reduce(when:on:),
      resolveSideEffect: runtime.sideEffects(for:),
      sendEvent: { await runtime.eventChannel.send($0) },
      getEvent: { await eventIterator.next() },
      eventMiddlewares: runtime.eventMiddlewares,
      stateMiddlewares: runtime.stateMiddlewares
    )
  }

  @discardableResult
  func register(
    taskInProgress task: Task<Void, Never>,
    cancelOn predicate: @Sendable @escaping (S) -> Bool
  ) -> Task<Void, Never> {
    // registering task for eventual cancellation
    let taskIndex = self.tasksInProgress.append(
      TaskInProgress(
        cancellationPredicate: predicate,
        task: task
      )
    )

    // cleaning when task is done
    return Task {
      await task.value
      self.tasksInProgress.remove(index: taskIndex)
    }
  }

  func cancelTasksInProgress(
    for state: S
  ) {
    self
      .tasksInProgress
      .indexedValues
      .filter { _, taskInProgress in taskInProgress.cancellationPredicate(state) }
      .forEach { index, taskInProgress in
        taskInProgress.task.cancel()
        self.tasksInProgress.remove(index: index)
      }
  }

  func cancelTasksInProgress() {
    self
      .tasksInProgress
      .values
      .forEach { taskInProgress in taskInProgress.task.cancel() }

    self.tasksInProgress.removeAll()
  }

  @discardableResult
  func process(
    event: E
  ) async -> [Task<Void, Never>] {
    // executes event middlewares for this event
    self.process(
      middlewares: self.eventMiddlewares.indexedValues,
      using: event,
      removeMiddleware: { index in self.eventMiddlewares.remove(index: index) }
    )
  }

  @discardableResult
  func process(
    state: S
  ) async -> [Task<Void, Never>] {
    // cancels tasks that are known to be cancellable for this state
    self.cancelTasksInProgress(for: state)

    // executes state middlewares for this state
    let removeTasksInProgressTasks = self.process(
      middlewares: self.stateMiddlewares.indexedValues,
      using: state,
      removeMiddleware: { index in self.stateMiddlewares.remove(index: index) }
    )

    // executes side effect for this state if any
    await self.executeSideEffect(for: state)

    return removeTasksInProgressTasks
  }

  @discardableResult
  func process<T>(
    middlewares: [(Int, Middleware<T>)],
    using value: T,
    removeMiddleware: @escaping (Int) async -> Void
  ) -> [Task<Void, Never>] {
    var removeTaskInProgressTasks = [Task<Void, Never>]()

    middlewares.forEach { (index, middleware) in
      let task: Task<Void, Never> = Task(priority: middleware.priority) {
        let shouldRemove = await middleware.execute(value)
        if shouldRemove {
          await removeMiddleware(index)
        }
      }

      // middlewares are not cancelled on any specific state
      let removeTaskInProgressTask = self.register(
        taskInProgress: task,
        cancelOn: { _ in false }
      )
      removeTaskInProgressTasks.append(removeTaskInProgressTask)
    }
    return removeTaskInProgressTasks
  }

  @discardableResult
  func executeSideEffect(for state: S) async -> Task<Void, Never>? {
    guard
      let output = self.resolveOutput(state),
      let sideEffect = self.resolveSideEffect(output),
      let events = sideEffect.execute(output) else { return nil }

    let task: Task<Void, Never> = Task(priority: sideEffect.priority) { [weak self] in
      do {
        for try await event in events {
          await self?.sendEvent(event)
        }
      } catch {
        // side effect cannot fail (should not be necessary to have a `for try await ...` loop but
        // AnyAsyncSequence masks the non throwable nature of side effects
        // could be fixed by saying the a side effect is (O) -> any AsyncSequence<E, Never>
      }
    }

    return self.register(
      taskInProgress: task,
      cancelOn: sideEffect.strategy.predicate
    )
  }

  func register(onTheFly execute: @Sendable @escaping (S) async -> Bool) {
    self.stateMiddlewares.append(
      Middleware<S>(execute: execute, priority: nil)
    )
  }

  deinit {
    self.cancelTasksInProgress()
  }
}
