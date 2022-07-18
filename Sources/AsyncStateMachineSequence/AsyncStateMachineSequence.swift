//
//  AsyncStateMachineSequence.swift
//  
//
//  Created by Thibault WITTEMBERG on 19/07/2022.
//

public final class AsyncStateMachineSequence<Element: Sendable>: AsyncSequence, Sendable {
  enum State {
    case idle
    case awaitingConsumer(producers: [Producer<Element>])
    case awaitingProducer(consumers: Set<Consumer<Element>>)
    case finished
  }

  enum ProducerDecision {
    case resumeImmediately(alsoResumingConsumer: Consumer<Element>)
    case resumeImmediatelyWithTerminaison
    case suspend
  }

  enum ConsumerDecision {
    case resumeImmediately(consumer: Consumer<Element>, byProducer: Producer<Element>)
    case resumeImmediatelyWithTerminaison
    case suspend
  }

  let state = ManagedCriticalState<State>(.idle)
  let identifierGenerator = IdentifierGenerator()

  public init(element elementType: Element.Type = Element.self) {}

  func cancelConsumer(identifier: Int) {
    let consumerContinuation = state.withCriticalRegion { state -> UnsafeContinuation<Element?, Never>? in
      switch state {
      case .awaitingProducer(var consumers):
        let consumer = consumers.remove(.placeHolder(identifier: identifier))
        if consumers.isEmpty {
          state = .idle
        } else {
          state = .awaitingProducer(consumers: consumers)
        }
        return consumer?.continuation
      case .idle:
        state = .awaitingProducer(consumers: [.cancelled(identifier: identifier)])
        return nil
      default:
        return nil
      }
    }

    consumerContinuation?.resume(returning: nil)
  }

  func computeConsumerDecision(
    consumerIdentifier: Int,
    continuation: UnsafeContinuation<Element?, Never>?
  ) -> ConsumerDecision {
    self.state.withCriticalRegion { state -> ConsumerDecision in
      switch state {
      case .idle:
        // the consumer will be resumed in the future, when a producer is available
        let newConsumer = Consumer(identifier: consumerIdentifier, continuation: continuation)
        state = .awaitingProducer(consumers: [newConsumer])
        return .suspend
      case .awaitingConsumer(var producers):
        // there is a match with an awaiting producer, the producer will be given the consumer's continuation to resume
        let newConsumer = Consumer(identifier: consumerIdentifier, continuation: continuation)
        let producer = producers.removeFirst()
        if producers.isEmpty {
          state = .idle
        } else {
          state = .awaitingConsumer(producers: producers)
        }
        return .resumeImmediately(consumer: newConsumer, byProducer: producer)
      case .awaitingProducer(var consumers):
        let decision: ConsumerDecision
        // there are already awaiting consumers, we add it to the queue and it will be resumed in the future
        if consumers.update(with: Consumer(identifier: consumerIdentifier, continuation: continuation)) != nil {
          consumers.remove(.placeHolder(identifier: consumerIdentifier))
          decision = .resumeImmediatelyWithTerminaison
        } else {
          decision = .suspend
        }
        if consumers.isEmpty {
          state = .idle
        } else {
          state = .awaitingProducer(consumers: consumers)
        }
        return decision
      case .finished:
        return .resumeImmediatelyWithTerminaison
      }
    }
  }

  func next(consumerIdentifier: Int) async -> Element? {
    await withUnsafeContinuation { (continuation: UnsafeContinuation<Element?, Never>) in
      let consumerDecision = self.computeConsumerDecision(
        consumerIdentifier: consumerIdentifier,
        continuation: continuation
      )

      switch consumerDecision {
      case let .resumeImmediately(consumer, byProducer):
        byProducer.continuation?.resume(returning: consumer)
      case .resumeImmediatelyWithTerminaison:
        continuation.resume(returning: nil)
      case .suspend:
        break
      }
    }
  }

  func terminateAll() {
    let (producers, consumers) = state.withCriticalRegion { state -> ([Producer<Element>], Set<Consumer<Element>>) in
      switch state {
      case .idle:
        state = .finished
        return ([], [])
      case .awaitingConsumer(let nexts):
        state = .finished
        return (nexts, [])
      case .awaitingProducer(let nexts):
        state = .finished
        return ([], nexts)
      case .finished:
        return ([], [])
      }
    }

    for producer in producers {
      producer.continuation?.resume(returning: nil)
    }

    for consumer in consumers {
      consumer.continuation?.resume(returning: nil)
    }
  }

  func _send(_ element: Element) async {
    await withTaskCancellationHandler {
      terminateAll()
    } operation: {
      let consumer = await withUnsafeContinuation { (continuation: UnsafeContinuation<Consumer<Element>?, Never>) in
        let producerDecision = state.withCriticalRegion { state -> ProducerDecision in
          switch state {
          case .idle:
            let producer = Producer(continuation: continuation)
            state = .awaitingConsumer(producers: [producer])
            return .suspend
          case .awaitingConsumer(var producers):
            let newProducer = Producer(continuation: continuation)
            producers.append(newProducer)
            state = .awaitingConsumer(producers: producers)
            return .suspend
          case .awaitingProducer(var consumers):
            let consumer = consumers.removeFirst()
            if consumers.count == 0 {
              state = .idle
            } else {
              state = .awaitingProducer(consumers: consumers)
            }
            return .resumeImmediately(alsoResumingConsumer: consumer)
          case .finished:
            return .resumeImmediatelyWithTerminaison
          }
        }

        switch producerDecision {
        case .resumeImmediately(let alsoResumingConsumer):
          continuation.resume(returning: alsoResumingConsumer)
        case .resumeImmediatelyWithTerminaison:
          continuation.resume(returning: nil)
        case .suspend:
          break
        }
      }

      consumer?.continuation?.resume(returning: element)
    }
  }

  public func send(_ element: Element) async {
    await self._send(element)
  }

  public func finish() {
    self.terminateAll()
  }

  public func makeAsyncIterator() -> Iterator {
    return Iterator(self)
  }

  public struct Iterator: AsyncIteratorProtocol, Sendable {
    let asyncStateMachineSequence: AsyncStateMachineSequence<Element>
//    var active: Bool = true

    init(_ asyncStateMachineSequence: AsyncStateMachineSequence<Element>) {
      self.asyncStateMachineSequence = asyncStateMachineSequence
    }

    /// Await the next sent element or finish.
    public mutating func next() async -> Element? {
//      guard self.active else {
//        return nil
//      }

      let consumerIdentifier = self.asyncStateMachineSequence.identifierGenerator.generate()

      return await withTaskCancellationHandler { [asyncStateMachineSequence] in
        asyncStateMachineSequence.cancelConsumer(identifier: consumerIdentifier)
      } operation: { [asyncStateMachineSequence] in
        await asyncStateMachineSequence.next(consumerIdentifier: consumerIdentifier)
      }

//      if let value = value {
//        return value
//      } else {
//        self.active = false
//        return nil
//      }
    }
  }
}

