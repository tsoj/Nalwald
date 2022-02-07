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
    math,
    algorithm

func infoString(
    iteration: int,
    value: Value,
    nodes: uint64,
    time: Duration,
    hashFull: int,
    pv: string,
    multiPvIndex = -1
): string =
    var scoreString = " score cp " & fmt"{value.toCp:>4}"
    if abs(value) >= valueCheckmate:
        if value < 0:
            scoreString = " score mate -"
        else:
            scoreString = " score mate "
        scoreString &= $(value.plysUntilCheckmate.float / 2.0).ceil.int

    let nps = 1000*(nodes div (time.inMilliseconds.uint64 + 1))

    result = "info"
    if multiPvIndex != -1:
        result &= " multipv " & fmt"{multiPvIndex:>2}"
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
    moveTime: Duration,
    numThreads: int
): bool =
    var
        bestMove = noMove
        iteration = 0

    for (value, pv, nodes, passedTime) in position.iterativeTimeManagedSearch(
        hashTable[],
        positionHistory,
        targetDepth,
        stop,
        movesToGo = movesToGo,
        increment = increment,
        timeLeft = timeLeft,
        moveTime = moveTime,
        numThreads = numThreads
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

type SearchResult = object
    move: Move
    value: Value
    pv: seq[Move]
    nodes: uint64
    passedTime: Duration

proc uciSearchMultiPv*(
    position: Position,
    hashTable: ptr HashTable,
    positionHistory: seq[Position],
    targetDepth: Ply,
    stop: ptr Atomic[bool],
    movesToGo: int16,
    increment, timeLeft: array[white..black, Duration],
    moveTime: Duration,
    multiPv: int,
    searchMoves: seq[Move],
    numThreads: int
): bool =

    if multiPv <= 0:
        return

    if multiPv == 1 and searchMoves.len == 0:
        return uciSearch(
            position,
            hashTable,
            positionHistory,
            targetDepth,
            stop,
            movesToGo,
            increment, timeLeft,
            moveTime,
            numThreads
        )

    var searchMoves = searchMoves
    if searchMoves.len == 0:
        for move in position.legalMoves():
            searchMoves.add move

    var iterators: seq[iterator (): SearchResult{.closure, gcsafe.}]

    for move in position.legalMoves():
        if move in searchMoves:
            var 
                newPosition = position
                newPositionHistory = positionHistory
            newPositionHistory.add position
            newPosition.doMove(move)
            proc genIter(newPosition: Position, move: Move): iterator (): SearchResult{.closure, gcsafe.} =
                return iterator(): SearchResult{.closure, gcsafe.} =
                    for (value, pv, nodes, passedTime) in iterativeTimeManagedSearch(
                        newPosition,
                        hashTable[],
                        newPositionHistory,
                        targetDepth - 1.Ply,
                        stop,
                        movesToGo = movesToGo,
                        increment = increment,
                        timeLeft = timeLeft,
                        moveTime = moveTime,
                        numThreads = numThreads
                    ):
                        yield SearchResult(move: move, value: value, pv: pv, nodes: nodes, passedTime: passedTime)
            iterators.add genIter(newPosition, move)
        
    var
        iteration = 1
        bestMove = noMove

    while true:
        
        var searchResults: seq[SearchResult]
        for iter in iterators:
            searchResults.add iter()
            searchResults[^1].value *= -1
            searchResults[^1].pv.insert(searchResults[^1].move, 0)
        
        for iter in iterators:
            if iter.finished:
                echo "bestmove ", bestMove.notation(position)
                return

        searchResults.sort do (x, y: auto) -> int: cmp(y.value, x.value)

        for i, searchResult in searchResults.pairs:
            if i+1 > multiPv:
                break
            echo iteration.infoString(
                searchResult.value,
                searchResult.nodes,
                searchResult.passedTime,
                hashTable[].hashFull,
                searchResult.pv.notation(position),
                i+1,
            )

        doAssert searchResults.len > 0
        let bestPv = searchResults[0].pv
        doAssert bestPv.len >= 1
        bestMove = bestPv[0]

        iteration += 1

