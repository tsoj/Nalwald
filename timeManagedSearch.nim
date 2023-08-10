import
    types,
    move,
    position,
    hashTable,
    rootSearch,
    evaluation,
    utils

import std/[
    atomics,
    threadpool,
    times
]

export Pv

type MoveTime = object
    maxTime, approxTime: Duration
func calculateMoveTime(moveTime, timeLeft, incPerMove: Duration, movesToGo, halfmovesPlayed: int16): MoveTime = 

    doAssert movesToGo >= 0
    let
        estimatedGameLength = 70
        estimatedMovesToGo = max(20, estimatedGameLength - halfmovesPlayed div 2)
        newMovesToGo = max(2, min(movesToGo, estimatedMovesToGo))

    result.maxTime = min(initDuration(milliseconds = timeLeft.inMilliseconds div 2), moveTime)
    result.approxTime = initDuration(milliseconds =
        clamp(timeLeft.inMilliseconds div newMovesToGo, 0, int.high div 2) +
        clamp(incPerMove.inMilliseconds, 0, int.high div 2)
        # clamping to int.high divided by 2 to make sure that adding these two things doesn't cause an int overflow
    )

    if incPerMove.inSeconds >= 2 or timeLeft > initDuration(minutes = 3):
        result.approxTime = (12 * result.approxTime) div 10
    elif incPerMove.inMilliseconds < 200 and timeLeft < initDuration(seconds = 30):
        result.approxTime = (8 * result.approxTime) div 10
        if movesToGo > 2:
            result.maxTime = min(initDuration(milliseconds = timeLeft.inMilliseconds div 4), moveTime)

iterator iterativeTimeManagedSearch*(
    position: Position,
    hashTable: var HashTable,
    positionHistory: seq[Position] = newSeq[Position](0),
    targetDepth: Ply = Ply.high,
    stop: ptr Atomic[bool] = nil,
    movesToGo: int16 = int16.high,
    increment = [white: DurationZero, black: DurationZero],
    timeLeft = [white: initDuration(milliseconds = int64.high), black: initDuration(milliseconds = int64.high)],
    moveTime = initDuration(milliseconds = int64.high),
    numThreads: int,
    maxNodes: uint64 = uint64.high,
    multiPv = 1,
    searchMoves: seq[Move] = @[],
    evaluation: proc(position: Position): Value {.noSideEffect.} = evaluate,
    requireRootPv = false
): tuple[pvList: seq[Pv], nodes: uint64, passedTime: Duration] =

    var stopFlag: Atomic[bool]
    var stop = if stop == nil: addr stopFlag else: stop

    stop[].store(false)

    let calculatedMoveTime = calculateMoveTime(
        moveTime, timeLeft[position.us], increment[position.us], movesToGo, position.halfmovesPlayed)
    var stopwatchResult = spawn stopwatch(stop, calculatedMoveTime.maxTime)

    let start = now()
    var
        startLastIteration = now()
        branchingFactors = newSeq[float](targetDepth.int)
        lastNumNodes = uint64.high

    var iteration = -1
    for (pvList, nodes, canStop) in iterativeDeepeningSearch(
        position,
        hashTable,
        stop,
        positionHistory,
        targetDepth,
        numThreads = if calculatedMoveTime.approxTime.inMilliseconds <= 100: 1 else: numThreads,
        maxNodes = maxNodes,
        multiPv = multiPv,
        searchMoves = searchMoves,
        evaluation = evaluation,
        requireRootPv = requireRootPv
    ):
        iteration += 1
        let totalPassedTime = now() - start
        let iterationPassedTime = (now() - startLastIteration)
        startLastIteration = now()

        yield (pvList: pvList, nodes: nodes, passedTime: iterationPassedTime)

        doAssert calculatedMoveTime.approxTime >= DurationZero
        
        branchingFactors[iteration] = nodes.float / lastNumNodes.float;
        lastNumNodes = if nodes <= 100_000: uint64.high else: nodes
        var averageBranchingFactor = branchingFactors[iteration]
        if iteration >= 4:
            averageBranchingFactor =
                (branchingFactors[iteration] +
                branchingFactors[iteration - 1] +
                branchingFactors[iteration - 2] +
                branchingFactors[iteration - 3])/4.0

        let estimatedTimeNextIteration =
            initDuration(milliseconds = (iterationPassedTime.inMilliseconds.float * averageBranchingFactor).int64)
        if estimatedTimeNextIteration + totalPassedTime > calculatedMoveTime.approxTime and iteration >= 4:
            break;

        if timeLeft[position.us] < initDuration(milliseconds = int64.high) and canStop:
            break

    stop[].store(true)
    discard ^stopwatchResult

proc timeManagedSearch*(
    position: Position,
    hashTable: var HashTable,
    positionHistory: seq[Position] = newSeq[Position](0),
    targetDepth: Ply = Ply.high,
    stop: ptr Atomic[bool] = nil,
    movesToGo: int16 = int16.high,
    increment = [white: DurationZero, black: DurationZero],
    timeLeft = [white: initDuration(milliseconds = int64.high), black: initDuration(milliseconds = int64.high)],
    moveTime = initDuration(milliseconds = int64.high),
    numThreads = 1,
    maxNodes: uint64 = uint64.high,
    multiPv = 1,
    searchMoves: seq[Move] = @[],
    evaluation: proc(position: Position): Value {.noSideEffect.} = evaluate,
    requireRootPv = false
): seq[Pv] =
    for (pvList, nodes, passedTime) in iterativeTimeManagedSearch(
        position,
        hashTable,
        positionHistory,
        targetDepth,
        stop,
        movesToGo = movesToGo,
        increment = increment,
        timeLeft = timeLeft,
        moveTime = moveTime,
        numThreads = numThreads,
        maxNodes = maxNodes,
        multiPv = multiPv,
        searchMoves = searchMoves,
        evaluation = evaluation,
        requireRootPv = requireRootPv
    ):
        result = pvList
