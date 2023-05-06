import
    types,
    move,
    position,
    hashTable,
    evaluation

import std/[
    atomics,
    times,
    options
]

type SearchOptions* {.requiresInit.} = object
    position*: Position
    hashTable*: ptr HashTable
    positionHistory*: seq[Position] = @[]
    targetDepth*: Ply = Ply.high
    stop*: ptr Atomic[bool] = nil
    movesToGo*: int16 = int16.high
    increment* = [white: DurationZero, black: DurationZero]
    timeLeft* = [white: initDuration(milliseconds = int64.high), black: initDuration(milliseconds = int64.high)]
    moveTime* = initDuration(milliseconds = int64.high)
    numThreads* = 1
    maxNodes*: uint64 = uint64.high
    multiPv*: Option[int] = none int
    skipMoves*: seq[Move] = @[]
    evaluation*: proc(position: Position): Value {.noSideEffect.} = (proc(position: Position): Value {.noSideEffect.})(evaluate)

proc hello(position: Position): Value {.noSideEffect.} =
    discard

var s = SearchOptions(
    position: Position(),
    hashTable: nil
    # evaluation: (proc(position: Position): Value)(evaluate) # TODO workaround for https://github.com/nim-lang/Nim/issues/21801 is fixed
)