import
    types,
    move,
    position,
    hashTable,
    rootSearch,
    evaluation,
    utils

import std/[atomics]

export Pv

type MoveTime = object
    maxTime, approxTime: Seconds
func calculateMoveTime(moveTime, timeLeft, incPerMove: Seconds, movesToGo, halfmovesPlayed: int16): MoveTime = 

    doAssert movesToGo >= 0
    let
        estimatedGameLength = 70
        estimatedMovesToGo = max(20, estimatedGameLength - halfmovesPlayed div 2)
        newMovesToGo = max(2, min(movesToGo, estimatedMovesToGo))

    result.maxTime = min(timeLeft / 2, moveTime)
    result.approxTime = incPerMove + timeLeft/newMovesToGo

    if incPerMove >= 2.Seconds or timeLeft > 180.Seconds:
        result.approxTime = result.approxTime * 1.2
    elif incPerMove < 0.2.Seconds and timeLeft < 30.Seconds:
        result.approxTime = result.approxTime * 0.8
        if movesToGo > 2:
            result.maxTime = min(timeLeft / 4, moveTime)

iterator iterativeTimeManagedSearch*(
    position: Position,
    hashTable: var HashTable,
    positionHistory: seq[Position] = newSeq[Position](0),
    targetDepth: Ply = Ply.high,
    stop: ptr Atomic[bool] = nil,
    movesToGo: int16 = int16.high,
    increment = [white: 0.Seconds, black: 0.Seconds],
    timeLeft = [white: Seconds.high, black: Seconds.high],
    moveTime = Seconds.high,
    numThreads: int,
    maxNodes: int64 = int64.high,
    multiPv = 1,
    searchMoves: seq[Move] = @[],
    evaluation: proc(position: Position): Value {.noSideEffect.} = evaluate,
    requireRootPv = false
): tuple[pvList: seq[Pv], nodes: int64, passedTime: Seconds] =

    var stopFlag: Atomic[bool]
    var stop = if stop == nil: addr stopFlag else: stop

    stop[].store(false)

    let calculatedMoveTime = calculateMoveTime(
        moveTime, timeLeft[position.us], increment[position.us], movesToGo, position.halfmovesPlayed)

    let start = secondsSince1970()
    var
        startLastIteration = secondsSince1970()
        branchingFactors = newSeq[float](targetDepth.int)
        lastNumNodes = int64.high

    var iteration = -1
    for (pvList, nodes, canStop) in iterativeDeepeningSearch(
        position,
        hashTable,
        stop,
        positionHistory,
        targetDepth,
        numThreads = if calculatedMoveTime.approxTime <= 0.1.Seconds: 1 else: numThreads,
        maxNodes = maxNodes,
        stopTime = start + calculatedMoveTime.maxTime,
        multiPv = multiPv,
        searchMoves = searchMoves,
        evaluation = evaluation,
        requireRootPv = requireRootPv
    ):
        iteration += 1
        let
            totalPassedTime = secondsSince1970() - start
            iterationPassedTime = (secondsSince1970() - startLastIteration)
        startLastIteration = secondsSince1970()

        yield (pvList: pvList, nodes: nodes, passedTime: iterationPassedTime)

        doAssert calculatedMoveTime.approxTime >= 0.Seconds
        
        branchingFactors[iteration] = nodes.float / lastNumNodes.float;
        lastNumNodes = if nodes <= 100_000: int64.high else: nodes
        var averageBranchingFactor = branchingFactors[iteration]
        if iteration >= 4:
            averageBranchingFactor =
                (branchingFactors[iteration] +
                branchingFactors[iteration - 1] +
                branchingFactors[iteration - 2] +
                branchingFactors[iteration - 3])/4.0

        let estimatedTimeNextIteration = iterationPassedTime * averageBranchingFactor
        if estimatedTimeNextIteration + totalPassedTime > calculatedMoveTime.approxTime and iteration >= 4:
            break;

        if timeLeft[position.us] < Seconds.high and canStop:
            break

    stop[].store(true)

proc timeManagedSearch*(
    position: Position,
    hashTable: var HashTable,
    positionHistory: seq[Position] = newSeq[Position](0),
    targetDepth: Ply = Ply.high,
    stop: ptr Atomic[bool] = nil,
    movesToGo: int16 = int16.high,
    increment = [white: 0.Seconds, black: 0.Seconds],
    timeLeft = [white: Seconds.high, black: Seconds.high],
    moveTime = Seconds.high,
    numThreads = 1,
    maxNodes: int64 = int64.high,
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
