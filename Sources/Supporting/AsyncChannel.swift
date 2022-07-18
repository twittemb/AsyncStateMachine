////===----------------------------------------------------------------------===//
////
//// This source file is part of the Swift Async Algorithms open source project
////
//// Copyright (c) 2022 Apple Inc. and the Swift project authors
//// Licensed under Apache License v2.0 with Runtime Library Exception
////
//// See https://swift.org/LICENSE.txt for license information
////
////===----------------------------------------------------------------------===//
//
//final class IdentifierGenerator: Sendable {
//  let state = ManagedCriticalState<Int>(0)
//
//  func generate() -> Int {
//    self.state.withCriticalRegion { current in
//      current += 1
//      return current
//    }
//  }
//}
//
//typealias Producer<Element> = UnsafeContinuation<UnsafeContinuation<Element?, Never>?, Never>
//
//struct Consumer<Element>: Hashable {
//  var identifier: Int
//  var continuation: UnsafeContinuation<Element?, Never>?
//  let cancelled: Bool
//
//  init(identifier: Int, continuation: UnsafeContinuation<Element?, Never>?, cancelled: Bool = false) {
//    self.identifier = identifier
//    self.continuation = continuation
//    self.cancelled = cancelled
//  }
//
//  static func placeHolder(identifier: Int) -> Consumer {
//    Consumer(
//      identifier: identifier,
//      continuation: nil,
//      cancelled: false
//    )
//  }
//
//  static func cancelled(identifier: Int) -> Consumer {
//    Consumer(
//      identifier: identifier,
//      continuation: nil,
//      cancelled: true
//    )
//  }
//
//  func hash(into hasher: inout Hasher) {
//    hasher.combine(self.identifier)
//  }
//
//  static func == (_ lhs: Consumer, _ rhs: Consumer) -> Bool {
//    return lhs.identifier == rhs.identifier
//  }
//}
//
///// A channel for sending elements from one task to another with back pressure.
/////
///// The `AsyncChannel` class is intended to be used as a communication type between tasks,
///// particularly when one task produces values and another task consumes those values. The back
///// pressure applied by `send(_:)` via the suspension/resume ensures that
///// the production of values does not exceed the consumption of values from iteration. This method
///// suspends after enqueuing the event and is resumed when the next call to `next()`
///// on the `Iterator` is made, or when `finish()` is called from another Task.
///// As `finish()` induces a terminal state, there is no need for a back pressure management.
///// This function does not suspend and will finish all the pending iterations.
//public final class AsyncChannel<Element: Sendable>: AsyncSequence, Sendable {
//  enum State {
//    case idle
//    case awaitingConsumer(producers: [Producer<Element>])
//    case awaitingProducer(consumers: Set<Consumer<Element>>)
//    case finished
//  }
//
//  let state = ManagedCriticalState<State>(.idle)
//  let identifierGenerator = IdentifierGenerator()
//
//  /// Create a new `AsyncChannel` given an element type.
//  public init(element elementType: Element.Type = Element.self) {}
//
//  func next() async -> Element? {
//    let consumerIdentifier = self.identifierGenerator.generate()
//
//    let value: Element? = await withTaskCancellationHandler { [weak self] in
//      self?.cancelConsumer(identifier: consumerIdentifier)
//    } operation: { [weak self] in
//      await self?.next(consumerIdentifier: consumerIdentifier)
//    }
//    return value
//  }
//
//  func cancelConsumer(identifier: Int) {
//    state.withCriticalRegion { state -> UnsafeContinuation<Element?, Never>? in
//      switch state {
//      case .awaitingProducer(var consumers):
//        let continuation = consumers.remove(.placeHolder(identifier: identifier))?.continuation
//        if consumers.isEmpty {
//          state = .idle
//        } else {
//          state = .awaitingProducer(consumers: consumers)
//        }
//        return continuation
//      case .idle:
//        state = .awaitingProducer(consumers: [.cancelled(identifier: identifier)])
//        return nil
//      default:
//        return nil
//      }
//    }?.resume(returning: nil)
//  }
//
//  func next(consumerIdentifier: Int) async -> Element? {
//    return await withUnsafeContinuation { continuation in
//      // the continuation will be resumed whenever a producer is available
//      // (either immediately or in the future)
//
//      var cancelled = false
//      var terminal = false
//
//      // UnsafeResumption aims to capture the continution and make it available outside the scope of
//      // the ManagedCriticalState
//      let unsafeResumption = state.withCriticalRegion { state -> UnsafeResumption<UnsafeContinuation<Element?, Never>?, Never>? in
//        switch state {
//        case .idle:
//          // the continuation will be resumed in the future, when a producer is available
//          let newConsumer = Consumer(identifier: consumerIdentifier, continuation: continuation)
//          state = .awaitingProducer(consumers: [newConsumer])
//          // returning nil as an UnsafeResumption, will make the `withUnsafeContinuation` function
//          // to suspend as long as the continuation added in the Consumer is not resumed by a producer
//          return nil
//        case .awaitingConsumer(var producers):
//          //
//          let producer = producers.removeFirst()
//          if producers.count == 0 {
//            state = .idle
//          } else {
//            state = .awaitingConsumer(producers: producers)
//          }
//          return UnsafeResumption(continuation: producer, success: continuation)
//        case .awaitingProducer(var consumers):
//          if consumers.update(with: Consumer(identifier: consumerIdentifier, continuation: continuation)) != nil {
//            consumers.remove(.placeHolder(identifier: consumerIdentifier))
//            cancelled = true
//          }
//          if consumers.isEmpty {
//            state = .idle
//          } else {
//            state = .awaitingProducer(consumers: consumers)
//          }
//          return nil
//        case .finished:
//          terminal = true
//          return nil
//        }
//      }
//
//      // if the unsafeResumption is nil, it means that the continuation will be resumed in the future,
//      // when a producer is available.
//      // if the unsafeResumption is not nill, it means that the continuation will be resumed immediately
//      // with an element from a producer
//      unsafeResumption?.resume()
//
//      if cancelled || terminal {
//        continuation.resume(returning: nil)
//      }
//    }
//  }
//
//  func terminateAll() {
//    let (producers, consumers) = state.withCriticalRegion { state -> ([Producer<Element>], Set<Consumer<Element>>) in
//      switch state {
//      case .idle:
//        state = .finished
//        return ([], [])
//      case .awaitingConsumer(let nexts):
//        state = .finished
//        return (nexts, [])
//      case .awaitingProducer(let nexts):
//        state = .finished
//        return ([], nexts)
//      case .finished:
//        return ([], [])
//      }
//    }
//
//    for producer in producers {
//      producer.resume(returning: nil)
//    }
//
//    for consumer in consumers {
//      consumer.continuation?.resume(returning: nil)
//    }
//  }
//
//  func _send(_ element: Element) async {
//    await withTaskCancellationHandler {
//      terminateAll()
//    } operation: {
//      let continuation: UnsafeContinuation<Element?, Never>? = await withUnsafeContinuation { continuation in
//        state.withCriticalRegion { state -> UnsafeResumption<UnsafeContinuation<Element?, Never>?, Never>? in
//          switch state {
//          case .idle:
//            state = .awaitingConsumer(producers: [continuation])
//            return nil
//          case .awaitingConsumer(var producers):
//            producers.append(continuation)
//            state = .awaitingConsumer(producers: producers)
//            return nil
//          case .awaitingProducer(var consumers):
//            let consumer = consumers.removeFirst().continuation
//            if consumers.count == 0 {
//              state = .idle
//            } else {
//              state = .awaitingProducer(consumers: consumers)
//            }
//            return UnsafeResumption(continuation: continuation, success: consumer)
//          case .finished:
//            return UnsafeResumption(continuation: continuation, success: nil)
//          }
//        }?.resume()
//      }
//      continuation?.resume(returning: element)
//    }
//  }
//
//  /// Send an element to an awaiting iteration. This function will resume when the next call to `next()` is made
//  /// or when a call to `finish()` is made from another Task.
//  /// If the channel is already finished then this returns immediately
//  public func send(_ element: Element) async {
//    await _send(element)
//  }
//
//  /// Send a finish to all awaiting iterations.
//  /// All subsequent calls to `next(_:)` will resume immediately.
//  public func finish() {
//    terminateAll()
//  }
//
//  /// Create an `Iterator` for iteration of an `AsyncChannel`
//  public func makeAsyncIterator() -> Iterator {
//    return Iterator(self)
//  }
//
//  /// The iterator for a `AsyncChannel` instance.
//  public struct Iterator: AsyncIteratorProtocol, Sendable {
//    let channel: AsyncChannel<Element>
//    var active: Bool = true
//
//    init(_ channel: AsyncChannel<Element>) {
//      self.channel = channel
//    }
//
//    /// Await the next sent element or finish.
//    public mutating func next() async -> Element? {
//      guard active else {
//        return nil
//      }
//
//      let value = await self.channel.next()
//
//      if let value = value {
//        return value
//      } else {
//        active = false
//        return nil
//      }
//    }
//  }
//}
