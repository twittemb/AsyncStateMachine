import Foundation

public final class AsyncStateMachineSequence<S, E, O>: AsyncSequence, Sendable
where S: DSLCompatible & Sendable, E: DSLCompatible & Sendable, O: DSLCompatible {
  public typealias Element = S
  public typealias AsyncIterator = Iterator

  let engine: Engine<S, E, O>
  let initialState: S

  public init(
    stateMachine: StateMachine<S, E, O>,
    runtime: Runtime<S, E, O>
  ) {
    self.engine = Engine(stateMachine: stateMachine, runtime: runtime)
    self.initialState = stateMachine.initial
  }

  public func send(_ event: E) async {
    await self.engine.sendEvent(event)
  }

  public func makeAsyncIterator() -> Iterator {
    Iterator(executor: self.engine)
  }

  public struct Iterator: AsyncIteratorProtocol {
    var currentState: S?
    let executor: Engine<S, E, O>

    init(executor: Engine<S, E, O>) {
      self.executor = executor
    }

    mutating func setCurrentState(_ state: S) async {
      self.currentState = state
      await self.executor.process(state: state)
    }

    public mutating func next() async -> Element? {
      let executor = self.executor

      return await withTaskCancellationHandler {
        guard let currentState = self.currentState else {
          // early returning the initial state for first iteration
          let initialState = self.executor.resolveInitialState()
          await self.setCurrentState(initialState)
          return self.currentState
        }

        var nextState: S?
        while nextState == nil {
          // requesting the next event
          guard let event = await self.executor.getEvent() else {
            // should not happen since no one can finish the channel
            return nil
          }

          // executing middlewares for the event
          await self.executor.process(event: event)

          // looking for the next non nil state according to transitions
          nextState = await self.executor.computeNextState(currentState, event)
        }

        guard let nextState = nextState else {
          self.currentState = nil
          return nil
        }

        await self.setCurrentState(nextState)
        return nextState
      } onCancel: {
        Task {
          await executor.cancelTasksInProgress()
        }
      }
    }
  }
}
