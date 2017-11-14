/*

Lemon: LALR(1) parser generator that generates a parser in C

    Author disclaimed copyright

    Public domain code.

Citron: Modifications to Lemon to generate a parser in Swift

    Copyright (C) 2017 Roopesh Chander <roop@roopc.net>

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

protocol CitronParser: class {

    // Types

    // Symbol code: Integer code representing terminal and non-terminal
    // symbols. Actual type depends on how many symbols there are. For
    // example, if numberOfSymbolCodes < 256, the type will be UInt8.
    // If there are n terminals in the grammar, the integers 1...n are used to
    // represent terminals and integers >n are used to represent non-terminals.
    // YYCODETYPE in lemon.
    associatedtype CitronSymbolCode: BinaryInteger

    // Token code: An enum representing the terminals. The raw value shall
    // be equal to the symbol code representing the terminal.
    associatedtype CitronTokenCode: RawRepresentable where CitronTokenCode.RawValue == CitronSymbolCode

    // Action code: Integer code representing the actions. Actual type depends on
    // how many actions there are.
    // YYACTIONTYPE in lemon.
    associatedtype CitronActionCode: BinaryInteger

    // Token: The type representing a terminal, defined using %token_type in the grammar.
    // ParseTOKENTYPE in lemon.
    associatedtype CitronToken

    // Symbol: An enum type representing any terminal or non-terminal symbol.
    // YYMINORTYPE in lemon.
    associatedtype CitronSymbol

    // Result: The type representing the start symbol of the grammar
    associatedtype CitronResult

    // Counts

    var yyInvalidSymbolCode: CitronSymbolCode { get } // YYNOCODE in lemon
    var yyNumberOfStates: Int { get } // YYNSTATE in lemon

    // Action tables

    var yyMaxShift: CitronActionCode { get } // YY_MAX_SHIFT in lemon
    var yyMinShiftReduce: CitronActionCode { get } // YY_MIN_SHIFTREDUCE in lemon
    var yyMaxShiftReduce: CitronActionCode { get } // YY_MAX_SHIFTREDUCE in lemon
    var yyMinReduce: CitronActionCode { get } // YY_MIN_REDUCE in lemon
    var yyMaxReduce: CitronActionCode { get } // YY_MIN_REDUCE in lemon
    var yyErrorAction: CitronActionCode { get } // YY_ERROR_ACTION in lemon
    var yyAcceptAction: CitronActionCode { get } // YY_ACCEPT_ACTION in lemon
    var yyNoAction: CitronActionCode { get } // YY_NO_ACTION in lemon
    var yyNumberOfActionCodes: Int { get } // YY_ACTTAB_COUNT in lemon

    var yyAction: [CitronActionCode] { get } // yy_action in lemon

    var yyLookahead: [CitronSymbolCode] { get } // yy_lookahead in lemon

    var yyShiftUseDefault: Int { get } // YY_SHIFT_USE_DFLT in lemon
    var yyShiftOffsetIndexMax: Int { get } // YY_SHIFT_COUNT in lemon
    var yyShiftOffsetMin: Int { get } // YY_SHIFT_MIN in lemon
    var yyShiftOffsetMax: Int { get } // YY_SHIFT_MAX in lemon
    var yyShiftOffset: [Int] { get } // yy_shift_ofst in lemon

    var yyReduceUseDefault: Int { get } // YY_REDUCE_USE_DFLT in lemon
    var yyReduceOffsetIndexMax: Int { get } // YY_REDUCE_COUNT in lemon
    var yyReduceOffsetMin: Int { get } // YY_REDUCE_MIN in lemon
    var yyReduceOffsetMax: Int { get } // YY_REDUCE_MAX in lemon
    var yyReduceOffset: [Int] { get } // yy_reduce_ofst in lemon

    var yyDefault: [CitronActionCode] { get } // yy_default in lemon

    // Fallback

    var yyHasFallback: Bool { get } // YYFALLBACK in lemon
    var yyFallback: [CitronSymbolCode] { get } // yyFallback in lemon

    // Wildcard

    var yyWildcard: CitronSymbolCode? { get }

    // Rules

    var yyRuleInfo: [(lhs: CitronSymbolCode, nrhs: UInt)] { get }

    // Stack

    var yyStack: [(state: Int /*FIXME*/, symbolCode: CitronSymbolCode, symbol: CitronSymbol)] { get set }
    var maxStackSize: Int? { get set }

    // Tracing

    var isTracingEnabled: Bool { get set }
    var yySymbolName: [String] { get } // yyTokenName in lemon
    var yyRuleText: [String] { get } // yyRuleName in lemon

    // Functions that shall be defined in the autogenerated code

    func yyTokenToSymbol(_ token: CitronToken) -> CitronSymbol
    func yyInvokeCodeBlockForRule(ruleNumber: Int) throws -> CitronSymbol
    func yyUnwrapResultFromSymbol(_ symbol: CitronSymbol) -> CitronResult

    // Error handling

    typealias CitronError = CitronParseError<CitronToken, CitronTokenCode>
}

// Error handling

enum CitronParseError<Token, TokenCode>: Error {
    case syntaxErrorAt(token: Token, tokenCode: TokenCode)
    case unexpectedEndOfInput
    case stackOverflow
}

// Parsing interface

extension CitronParser {
    func consume(token: CitronToken, code tokenCode: CitronTokenCode) throws {
        let symbolCode = tokenCode.rawValue
        tracePrint("Input:", symbolNameFor(code:symbolCode))
        while (!yyStack.isEmpty) {
            let action = yyFindShiftAction(lookAhead: symbolCode)
            if (action <= yyMaxShiftReduce) {
                try yyShift(yyNewState: Int(action), symbolCode: symbolCode, token: token)
                break
            } else if (action <= yyMaxReduce) {
                let resultSymbol = try yyReduce(ruleNumber: Int(action - yyMinReduce))
                assert(resultSymbol == nil) // Can be non-nil only in endParsing()
                continue
            } else if (action == yyErrorAction) {
                throw CitronError.syntaxErrorAt(token: token, tokenCode: tokenCode)
            } else {
                fatalError("Unexpected action")
            }
        }
        traceStack()
    }

    func endParsing() throws -> CitronResult {
        tracePrint("End of input")
        while (!yyStack.isEmpty) {
            let action = yyFindShiftAction(lookAhead: 0)
            assert(action > yyMaxShiftReduce)
            if (action <= yyMaxReduce) {
                let resultSymbol = try yyReduce(ruleNumber: Int(action - yyMinReduce))
                if let resultSymbol = resultSymbol {
                    tracePrint("Parse successful")
                    return yyUnwrapResultFromSymbol(resultSymbol)
                }
                continue
            } else if (action == yyErrorAction) {
                throw CitronError.unexpectedEndOfInput
            } else {
                fatalError("Unexpected action")
            }
        }
        fatalError("Unexpected stack underflow")
    }

    func reset() {
        tracePrint("Resetting the parser")
        while (yyStack.count > 1) {
            yyPop()
        }
    }
}

// Private methods

private extension CitronParser {

    func yyPush(state: Int, symbolCode: CitronSymbolCode, symbol: CitronSymbol) throws {
        if (maxStackSize != nil && yyStack.count >= maxStackSize!) {
            // Can't grow stack anymore
            throw CitronError.stackOverflow
        }
        yyStack.append((state: state, symbolCode: symbolCode, symbol: symbol))
    }

    func yyPop() {
        let last = yyStack.popLast()
        if let last = last {
            tracePrint("Popping", symbolNameFor(code:last.symbolCode))
        }
    }

    func yyPopAll() {
        while (!yyStack.isEmpty) {
            yyPop()
        }
    }

    func yyFindShiftAction(lookAhead la: CitronSymbolCode) -> CitronActionCode {
        guard (!yyStack.isEmpty) else { fatalError("Unexpected empty stack") }
        let state = yyStack.last!.state
        if (state >= yyMinReduce) {
            return CitronActionCode(state)
        }
        var i: Int = 0
        var lookAhead = la
        while (true) {
            assert(state < yyShiftOffset.count)
            assert(lookAhead != yyInvalidSymbolCode)
            i = yyShiftOffset[state] + Int(lookAhead)
            if (i < 0 || i >= yyNumberOfActionCodes || yyLookahead[i] != lookAhead) {
                // Fallback
                if let fallback = yyFallback[safe: lookAhead], fallback > 0 {
                    tracePrint("Fallback:", symbolNameFor(code: lookAhead), "=>", symbolNameFor(code:fallback))
                    precondition((yyFallback[safe: fallback] ?? -1) == 0, "Fallback loop detected")
                    lookAhead = fallback
                    continue
                }
                // Wildcard
                if let yyWildcard = yyWildcard {
                    let wildcard = yyWildcard
                    let j = i - Int(lookAhead) + Int(wildcard)
                    if ((yyShiftOffsetMin + Int(wildcard) >= 0 || j >= 0) &&
                        (yyShiftOffsetMax + Int(wildcard) < yyNumberOfActionCodes || j < yyNumberOfActionCodes) &&
                        (yyLookahead[j] == wildcard && lookAhead > 0)) {
                        tracePrint("Wildcard:", symbolNameFor(code: lookAhead), "=>", symbolNameFor(code: wildcard))
                        return yyAction[j]
                    }
                }
                // No fallback and no wildcard. Pick the default action for this state.
                return yyDefault[Int(state)]
            } else {
                // Pick action from action table
                return yyAction[i]
            }
        }
    }

    func yyFindReduceAction(state: Int, lookAhead: CitronSymbolCode) -> CitronActionCode {
        assert(state < yyReduceOffset.count)
        var i = yyReduceOffset[state]

        assert(i != yyReduceUseDefault)
        assert(lookAhead != yyInvalidSymbolCode)
        i += Int(lookAhead)

        assert(i >= 0 && i < yyNumberOfActionCodes)
        assert(yyLookahead[i] == lookAhead)

        return yyAction[i]
    }

    func yyShift(yyNewState: Int, symbolCode: CitronSymbolCode, token: CitronToken) throws {
        var newState = yyNewState
        if (newState > yyMaxShift) {
            newState += Int(yyMinReduce) - Int(yyMinShiftReduce)
        }
        try yyPush(state: newState, symbolCode: symbolCode, symbol: yyTokenToSymbol(token))
        tracePrint("Shift:", symbolNameFor(code:symbolCode))
        if (newState < yyNumberOfStates) {
            tracePrint("       and go to state", "\(newState)")
        }
    }

    // yyReduce: Reduces using the specified rule number.
    // If the parse is accepted, returns the result symbol, else returns nil.
    func yyReduce(ruleNumber: Int) throws -> CitronSymbol? {
        assert(ruleNumber < yyRuleInfo.count)
        guard (!yyStack.isEmpty) else { fatalError("Unexpected empty stack") }
        tracePrint("Reducing with rule:", yyRuleText[ruleNumber])

        let resultSymbol = try yyInvokeCodeBlockForRule(ruleNumber: ruleNumber)

        let ruleInfo = yyRuleInfo[ruleNumber]
        let lhsSymbolCode = ruleInfo.lhs
        let numberOfRhsSymbols = ruleInfo.nrhs
        assert(yyStack.count > numberOfRhsSymbols)
        let nextState = yyStack[yyStack.count - 1 - Int(numberOfRhsSymbols)].state
        let action = yyFindReduceAction(state: nextState, lookAhead: lhsSymbolCode)

        // It is not possible for a REDUCE to be followed by an error
        precondition(action != yyErrorAction,
                     "Unexpected error action after a reduce")

        for _ in (0 ..< numberOfRhsSymbols) {
            yyPop()
        }

        if (action == yyAcceptAction) {
            return resultSymbol
        } else {
            let newState = action
            try yyPush(state: Int(newState), symbolCode: lhsSymbolCode, symbol: resultSymbol)
            tracePrint("Shift:", symbolNameFor(code:lhsSymbolCode))
            if (newState < yyNumberOfStates) {
                tracePrint("       and go to state", "\(newState)")
            }
            traceStack()
            return nil
        }
    }
}

// Private helpers

private extension CitronParser {
    func isShift(actionCode i: CitronActionCode) -> Bool {
        return i >= 0 && i <= yyMaxShift
    }

    func isShiftReduce(actionCode i: CitronActionCode) -> Bool {
        return i >= yyMinShiftReduce && i <= yyMaxShiftReduce
    }

    func isReduce(actionCode i: CitronActionCode) -> Bool {
        return i >= yyMinReduce && i <= yyMaxReduce
    }
}

private extension CitronParser {
    func tracePrint(_ msg: String) {
        if (isTracingEnabled) {
            print("\(msg)")
        }
    }

    func tracePrint(_ msg: String, _ closure: @autoclosure () -> CustomDebugStringConvertible) {
        if (isTracingEnabled) {
            print("\(msg) \(closure())")
        }
    }

    func tracePrint(_ msg: String, _ closure: @autoclosure () -> CustomDebugStringConvertible,
                    _ msg2: String, _ closure2: @autoclosure () -> CustomDebugStringConvertible) {
        if (isTracingEnabled) {
            print("\(msg) \(closure()) \(msg2) \(closure2())")
        }
    }

    func symbolNameFor(code i: CitronSymbolCode) -> String {
        if (i > 0 && i < yySymbolName.count) { return yySymbolName[Int(i)] }
        return "?"
    }

    func traceStack() {
        if (isTracingEnabled) {
            print("STACK contents:")
            for (i, e) in yyStack.enumerated() {
                print("    \(i): (state: \(e.state), symbol: \(symbolNameFor(code:e.symbolCode)) [\(e.symbolCode)])")
            }
        }
    }
}

private extension Array {
    subscript<I: BinaryInteger>(safe i: I) -> Element? {
        get {
            let index = Int(i)
            return index < self.count ? self[index] : nil
        }
    }
}

