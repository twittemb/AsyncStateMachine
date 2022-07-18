//
//  Pipe.swift
//
//
//  Created by Thibault WITTEMBERG on 25/06/2022.
//

public final class Pipe<E>: Sendable
where E: DSLCompatible {
  typealias Receiver = @Sendable (E) async -> Void
  let receiver = ManagedCriticalState<Receiver?>(nil)

  public init() {}

  func push(_ event: E) async {
    await self.receiver.criticalState?(event)
  }

  func register(receiver: @Sendable @escaping (E) async -> Void) {
    self.receiver.apply(criticalState: receiver)
  }
}
