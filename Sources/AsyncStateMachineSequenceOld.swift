//import Foundation
//
//public final class AsyncStateMachineSequence<S, E, O>: AsyncSequence, Sendable
//where S: DSLCompatible & Sendable, E: DSLCompatible & Sendable, O: DSLCompatible {
//  public typealias Element = S
//  public typealias AsyncIterator = Iterator
//
//  let initialState: S
//  let eventChannel: AsyncChannel<E>
//  let currentState: ManagedCriticalState<S?>
//  let engine: Engine<S, E, O>
//
//  public init(
//    stateMachine: StateMachine<S, E, O>,
//    runtime: Runtime<S, E, O>
//  ) {
//    self.initialState = stateMachine.initial
//    self.eventChannel = AsyncChannel<E>()
//    self.currentState = ManagedCriticalState(nil)
//    self.engine = Engine(
//      resolveOutput: stateMachine.output(for:),
//      computeNextState: stateMachine.reduce(when:on:),
//      resolveSideEffect: runtime.sideEffects(for:),
//      sendEvent: eventChannel.send,
//      eventMiddlewares: runtime.eventMiddlewares,
//      stateMiddlewares: runtime.stateMiddlewares
//    )
//
//    // As pipes are retained as long as there is a sender using it,
//    // the eventChannel of the receiver will also be retained, even though
//    // the receiver state machine sequence might be cancelled or deinit.
//    // That is why it is necesssary to have a weak reference on the eventChannel here.
//    // Doing so, the eventChannel will be deallocated event if a pipe is using is.
//    // Pipes are resilient to nil receiver functions.
//    runtime.pipeReceivers.forEach { [weak eventChannel] pipeReceiver in
//      pipeReceiver.update(receiver: eventChannel?.send)
//    }
//  }
//
//  @Sendable public func send(_ event: E) async {
//    await self.eventChannel.send(event)
//  }
//
//  public func makeAsyncIterator() -> Iterator {
//    Iterator(
//      asyncStateMachineSequence: self,
//      eventIterator: self.eventChannel.makeAsyncIterator()
//    )
//  }
//
//  func apply(state: S) async {
//    self.currentState.apply(criticalState: state)
//    await self.engine.process(state: state)
//  }
//
//  func applyInitialState() async {
//    await self.apply(state: self.initialState)
//  }
//
//  /// Process the current event by executing middlewares, computing the next state, executing side effects
//  /// - Parameter event: the event to process
//  /// - Returns: true if the event has led to a non nil next state, false otherwise
//  func process(event: E) async -> Bool {
//    guard let state = self.currentState.criticalState else { return false }
//
//    // event middlewares
//    await self.engine.process(event: event)
//
//    // next state computation
//    guard let nextState = await self.engine.computeNextState(state, event) else { return false }
//
//    // state middlewares and side effects
//    await self.apply(state: nextState)
//  }
//
//  func cancel() async {
//    await self.engine.cancelTasksInProgress()
//  }
//
//  public struct Iterator: AsyncIteratorProtocol {
//    let asyncStateMachineSequence: AsyncStateMachineSequence<S, E, O>
//    var eventIterator: AsyncChannel<E>.AsyncIterator
//
//    init(
//      asyncStateMachineSequence: AsyncStateMachineSequence<S, E, O>,
//      eventIterator: AsyncChannel<E>.AsyncIterator
//    ) {
//      self.asyncStateMachineSequence = asyncStateMachineSequence
//      self.eventIterator = eventIterator
//    }
//
//    public mutating func next() async -> Element? {
//      let asyncStateMachineSequence = self.asyncStateMachineSequence
//
//      return await withTaskCancellationHandler {
//        guard let currentState = self.currentState else {
//          // early returning the initial state for first iteration
//          self.currentState = asyncStateMachineSequence.initialState
//
//          // executing middlewares/side effect for the new state
//          await asyncStateMachineSequence.process(state: self.asyncStateMachineSequence.initialState)
//
//          return self.currentState
//        }
//
//        var nextState: S?
//        while nextState == nil {
//          guard !Task.isCancelled else { return nil }
//
//          // requesting the next event
//          guard let event = await self.eventIterator.next() else {
//            // should not happen since no one can finish the channel
//            return nil
//          }
//
//          // executing middlewares for the event
//          await asyncStateMachineSequence.process(event: event)
//
//          // looking for the next non nil state according to transitions
//          nextState = await asyncStateMachineSequence.nextState(state: currentState, event: event)
//        }
//
//        // cannot happen due to previous loop
//        // TODO: should consider the notion of final state that could end the sequence
//        guard let nextState = nextState else {
//          self.currentState = nil
//          return nil
//        }
//
//        self.currentState = nextState
//
//        // executing middlewares/side effect for the new state
//        await asyncStateMachineSequence.process(state: nextState)
//
//        return nextState
//      } onCancel: {
//        Task {
//          // TODO: should cancel only when no more clients
//          await asyncStateMachineSequence.cancel()
//        }
//      }
//    }
//  }
//}
