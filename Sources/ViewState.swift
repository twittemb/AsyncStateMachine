//
//  ViewState.swift
//  
//
//  Created by Thibault WITTEMBERG on 02/07/2022.
//

import Foundation

@MainActor
public class ViewState<S, E, O>: ObservableObject
where S: DSLCompatible & Equatable, E: DSLCompatible, O: DSLCompatible {
  @Published public var state: S

  let asyncStateMachineSequence: AsyncStateMachineSequence<S, E, O>

  public init(asyncStateMachineSequence: AsyncStateMachineSequence<S, E, O>) {
    self.asyncStateMachineSequence = asyncStateMachineSequence
    self.state = self.asyncStateMachineSequence.initialState
  }

  nonisolated public func send(_ event: E) async {
    await self.asyncStateMachineSequence.send(event)
  }

  nonisolated public func send(
    _ event: E,
    resumeWhen predicate: @escaping (S) -> Bool
  ) async {
    await withUnsafeContinuation { [asyncStateMachineSequence] (continuation: UnsafeContinuation<Void, Never>) in
      Task {
        await asyncStateMachineSequence.engine.register(onTheFly: { state in
          if predicate(state) {
            continuation.resume()
            // middleware will be unregistered after the predicate has been matched
            return true
          }
          return false
        })

        await asyncStateMachineSequence.send(event)
      }
    }
  }

  nonisolated public func send(
    _ event: E,
    resumeWhen state: S
  ) async {
    await self.send(
      event,
      resumeWhen: { inputState in inputState.matches(state) }
    )
  }

  nonisolated public func send<StateAssociatedValue>(
    _ event: E,
    resumeWhen state: @escaping (StateAssociatedValue) -> S
  ) async {
    await self.send(
      event,
      resumeWhen: { inputState in inputState.matches(state) }
    )
  }

  public func send(
    _ event: E,
    resumeWhen states: OneOf<S>
  ) async {
    await self.send(
      event,
      resumeWhen: { inputState in states.predicate(inputState) }
    )
  }

  func publish(state: S) {
    if state != self.state {
      self.state = state
    }
  }

  nonisolated public func start() async {
    for await state in self.asyncStateMachineSequence {
      await self.publish(state: state)
    }
  }
}

#if canImport(SwiftUI)
import SwiftUI

public extension ViewState {
  func binding(send event: @escaping (S) -> E) -> Binding<S> {
    Binding {
      self.state
    } set: { [asyncStateMachineSequence] value in
      Task {
        await asyncStateMachineSequence.send(event(value))
      }
    }
  }

  func binding(send event: E) -> Binding<S> {
    self.binding(send: { _ in event })
  }

  func binding<T>(keypath: KeyPath<S, T>, send event: @escaping (T) -> E) -> Binding<T> {
    Binding {
      self.state[keyPath: keypath]
    } set: { [asyncStateMachineSequence] value in
      Task {
        await asyncStateMachineSequence.send(event(value))
      }
    }
  }

  func binding<T>(keypath: KeyPath<S, T>, send event: E) -> Binding<T> {
    self.binding(keypath: keypath, send: { _ in event })
  }
}
#endif
