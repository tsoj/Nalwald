import
    types,
    move,
    position,
    positionUtils,
    timeManagedSearch,
    hashTable,
    evaluation,
    atomics,
    times,
    strformat,
    strutils,
    math

func infoString(
    iteration: int,
    value: Value,
    nodes: uint64,
    time: Duration,
    hashFull: int,
    pv: string
): string =
    var scoreString = " score cp " & fmt"{value.toCp:>4}"
    if abs(value) >= valueCheckmate:
        if value < 0:
            scoreString = " score mate -"
        else:
            scoreString = " score mate "
        scoreString &= $(value.plysUntilCheckmate.Float / 2.0).ceil.int

    let nps = 1000*(nodes div (time.inMilliseconds.uint64 + 1))

    result = "info"
    result &= " depth " & fmt"{iteration+1:>2}"
    result &= " time " & fmt"{time.inMilliseconds:>6}"
    result &= " nodes " & fmt"{nodes:>9}"
    result &= " nps " & fmt"{nps:>7}"
    result &= " hashfull " & fmt"{hashFull:>5}"
    result &= scoreString
    result &= " pv " & pv

proc uciSearch*(
    position: Position,
    hashTable: ptr HashTable,
    positionHistory: seq[Position],
    targetDepth: Ply,
    stop: ptr Atomic[bool],
    movesToGo: int16,
    increment, timeLeft: array[white..black, Duration],
    moveTime: Duration
): bool =
    var bestMove = noMove    
    var iteration = 0
    for (value, pv, nodes, passedTime) in position.iterativeTimeManagedSearch(
        hashTable[],
        positionHistory,
        targetDepth,
        stop,
        movesToGo = movesToGo,
        increment = increment,
        timeLeft = timeLeft,
        moveTime = moveTime
    ):
        doAssert pv.len >= 1
        bestMove = pv[0]

        # uci info
        echo iteration.infoString(
            value,
            nodes,
            passedTime,
            hashTable[].hashFull,
            pv.notation(position)
        )

        iteration += 1

    echo "bestmove ", bestMove.notation(position)