//@testable import AsyncStateMachine
//import XCTest
//
//enum State: DSLCompatible, Equatable {
//  case s1(value: String)
//  case s2(value: String)
//  case s3(value: String)
//  case s4(value: String)
//  case s5(value: String)
//  case s6(value: String)
//  case s7(value: String)
//  case s8(value: String)
//  case s9(value: String)
//  case s10(value: String)
//  case s11(value: String)
//  case s12(value: String)
//
//  var value: String {
//    switch self {
//    case .s1(let value): return value
//    case .s2(let value): return value
//    case .s3(let value): return value
//    case .s4(let value): return value
//    case .s5(let value): return value
//    case .s6(let value): return value
//    case .s7(let value): return value
//    case .s8(let value): return value
//    case .s9(let value): return value
//    case .s10(let value): return value
//    case .s11(let value): return value
//    case .s12(let value): return value
//    }
//  }
//}
//
//enum Event: DSLCompatible, Equatable {
//  case e1(value: String)
//  case e2(value: String)
//  case e3(value: String)
//  case e4(value: String)
//  case e5(value: String)
//  case e6(value: String)
//  case e7(value: String)
//  case e8(value: String)
//  case e9(value: String)
//  case e10(value: String)
//  case e11(value: String)
//  case e12(value: String)
//
//  var value: String {
//    switch self {
//    case .e1(let value): return value
//    case .e2(let value): return value
//    case .e3(let value): return value
//    case .e4(let value): return value
//    case .e5(let value): return value
//    case .e6(let value): return value
//    case .e7(let value): return value
//    case .e8(let value): return value
//    case .e9(let value): return value
//    case .e10(let value): return value
//    case .e11(let value): return value
//    case .e12(let value): return value
//    }
//  }
//}
//
//enum Output: DSLCompatible, Equatable {
//  case o1(value: String)
//  case o2(value: String)
//  case o3(value: String)
//}
//
//let stateMachine = StateMachine<State, Event, Output>(initial: State.s1(value: "s1")) {
//  When(states: OneOf {
//    State.s1(value:)
//    State.s2(value:)
//    State.s3(value:)
//    State.s4(value:)
//    State.s5(value:)
//    State.s6(value:)
//    State.s7(value:)
//    State.s8(value:)
//    State.s9(value:)
//    State.s10(value:)
//    State.s11(value:)
//    State.s12(value:)
//  }) { state in
//    Execute(output: Output.o1(value: state.value))
//  } transitions: { state in
//    On(events: OneOf {
//      Event.e1(value:)
//      Event.e2(value:)
//      Event.e3(value:)
//      Event.e4(value:)
//      Event.e5(value:)
//      Event.e6(value:)
//      Event.e7(value:)
//      Event.e8(value:)
//      Event.e9(value:)
//      Event.e10(value:)
//      Event.e11(value:)
//      Event.e12(value:)
//    }) { _ in
//      Guard(predicate: !state.value.isEmpty)
//    } transition: { event in
//      Transition(to: State.s2(value: state.value + event.value))
//    }
//  }
//}
//
//final class AsyncStatMachineSequenceTests: XCTestCase {
////  func testPerformance() async {
////    measure {
////      let exp = expectation(description: "task")
////      let task = Task {
////        for s in (1...12) {
////          for e in (1...12) {
////            _ = await stateMachine.reduce(when: State.s1(value: "s\(s)"), on: Event.e1(value: "e\(e)"))
////          }
////        }
////        exp.fulfill()
////      }
////      wait(for: [exp], timeout: 10.0)
////      task.cancel()
////    }
////  }
//
//  func test_states_and_events_match_the_expected_flow() async {
//    // Given
//    let stateMachine = StateMachine<State, Event, Output>(initial: State.s1(value: "value")) {
//      When(state: State.s1(value:)) { stateValue in
//        Execute(output: Output.o1(value: stateValue))
//      } transitions: { stateValue in
//
//        On(event: Event.e1(value:)) { eventValue in
//          Guard(predicate: stateValue.isEmpty || eventValue.isEmpty)
//        } transition: { eventValue in
//          Transition(to: State.s2(value: "new value"))
//        }
//
//        On(event: Event.e2(value:)) { eventValue in
//          Guard(predicate: !stateValue.isEmpty && !eventValue.isEmpty)
//        } transition: { eventValue in
//          Transition(to: State.s3(value: eventValue))
//        }
//      }
//
//      When(state: State.s2(value:)) { stateValue in
//        Execute(output: Output.o2(value: stateValue))
//      } transitions: { stateValue in
//        On(event: Event.e3(value:)) { eventValue in
//          Guard(predicate: stateValue.isEmpty || eventValue.isEmpty)
//        } transition: { eventValue in
//          Transition(to: State.s4(value: eventValue))
//        }
//
//        On(event: Event.e4(value:)) { eventValue in
//          Guard(predicate: !stateValue.isEmpty && !eventValue.isEmpty)
//        } transition: { eventValue in
//          Transition(to: State.s5(value: eventValue))
//        }
//      }
//
//      When(states: OneOf {
//        State.s4(value:)
//        State.s5(value:)
//      }) { state in
//        Execute(output: Output.o3(value: state.value))
//      } transitions: { state in
//        On(event: Event.e5(value:)) { eventValue in
//          Guard(predicate: state.value.isEmpty || eventValue.isEmpty)
//        } transition: { eventValue in
//          Transition(to: State.s6(value: eventValue))
//        }
//
//        On(event: Event.e6(value:)) { eventValue in
//          Guard(predicate: !state.value.isEmpty && !eventValue.isEmpty)
//        } transition: { eventValue in
//          Transition(to: State.s7(value: eventValue))
//        }
//      }
//    }
//
//    let receivedStates = ManagedCriticalState<[State]>([])
//    let receivedEvents = ManagedCriticalState<[Event]>([])
//
//    let runtime = Runtime<State, Event, Output>()
//      .map(output: Output.o1(value:), to: { _ in Event.e1(value: "") })
//      .map(output: Output.o2(value:), to: { outputValue in Event.e4(value: outputValue) })
//      .map(output: Output.o3(value:), to: { outputValue in Event.e6(value: outputValue) })
//      .register(middleware: { state in receivedStates.withCriticalRegion{ $0.append(state) } })
//      .register(middleware: { event in receivedEvents.withCriticalRegion{ $0.append(event) } })
//
//    let sequence = AsyncStateMachineSequence(stateMachine: stateMachine, runtime: runtime)
//
//    // When
//    for await state in sequence {
//      print(state)
//      if state == State.s7(value: "new value") {
//        break
//      }
//    }
//
//    // Then
//    let expectedStates = [
//      State.s1(value: "value"),
//      State.s2(value: "new value"),
//      State.s5(value: "new value"),
//      State.s7(value: "new value")
//    ]
//
//    let expectedEvents = [
//      Event.e1(value: ""),
//      Event.e4(value: "new value"),
//      Event.e6(value: "new value"),
//    ]
//
//    XCTAssertEqual(receivedStates.criticalState, expectedStates)
//    XCTAssertEqual(receivedEvents.criticalState, expectedEvents)
//  }
//}
