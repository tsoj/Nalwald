import
    types,
    move,
    position,
    positionUtils,
    timeManagedSearch,
    hashTable,
    evaluation

import std/[
    terminal,
    atomics,
    times,
    strformat,
    strutils,
    math,
    algorithm
]

func printInfoString(
    iteration: int,
    value: Value,
    nodes: uint64,
    time: Duration,
    hashFull: int,
    pv: string,
    beautiful: bool,
    multiPvIndex = -1
) =
    {.cast(noSideEffect).}:
        proc print(text: string, style: set[Style] = {}, color = fgDefault) =
            if beautiful:
                stdout.styledWrite color, style, text
            else:
                stdout.write text

        proc printKeyValue(key, value: string, valueColor: ForegroundColor, style: set[Style] = {}) =
            print " " & key & " ", {styleItalic}
            print value, style, valueColor

        print "info", {styleDim}

        if multiPvIndex != -1:
            printKeyValue("multipv", fmt"{multiPvIndex:>2}", fgMagenta)
        printKeyValue("depth", fmt"{iteration+1:>2}", fgBlue)
        printKeyValue("time", fmt"{time.inMilliseconds:>6}", fgCyan)
        printKeyValue("nodes", fmt"{nodes:>9}", fgYellow)

        let nps = 1000*(nodes div max(1, time.inMilliseconds).uint64)
        printKeyValue("nps", fmt"{nps:>7}", fgGreen)
        
        printKeyValue("hashfull", fmt"{hashFull:>5}", fgCyan, if hashFull <= 500: {styleDim} else: {})


        if abs(value) >= valueCheckmate:
            
            print " score ", {styleItalic}
            let
                valueString = (if value < 0: "mate -" else: "mate ") & $(value.plysUntilCheckmate.float / 2.0).ceil.int
                color = if value > 0: fgGreen else: fgRed

            print valueString, {styleBright}, color

        else:
            let
                valueString = fmt"{value.toCp:>4}"
                style: set[Style] = if value.abs < 100.cp: {styleDim} else: {}

            print " score cp ", {styleItalic}
            if value.abs <= 10.cp:
                print valueString, style
            else:
                let color = if value > 0: fgGreen else: fgRed
                print valueString, style, color
                


            printKeyValue("pv", pv, fgBlue, {styleBright})

        echo ""

func bestMoveString(move: Move, position: Position): string =
    let moveNotation = move.notation(position)
    if move in position.legalMoves:
        return "bestmove " & moveNotation
    else:
        result = "info string found illegal move: " & moveNotation & "\n"
        if position.legalMoves.len > 0:
            result &= "bestmove "  & position.legalMoves[0].notation(position)
        else:
            result &= "info string no legal move available"
        

type SearchInfo* = object
    position*: Position
    hashTable*: ptr HashTable
    positionHistory*: seq[Position]
    targetDepth*: Ply
    stop*: ptr Atomic[bool]
    movesToGo*: int16
    increment*, timeLeft*: array[white..black, Duration]
    moveTime*: Duration
    multiPv*: int
    searchMoves*: seq[Move]
    numThreads*: int
    nodes*: uint64
    uciCompatibleOutput*: bool

proc uciSearchSinglePv(searchInfo: SearchInfo) =
    var
        bestMove = noMove
        iteration = 0

    for (value, pv, nodes, passedTime) in searchInfo.position.iterativeTimeManagedSearch(
        searchInfo.hashTable[],
        searchInfo.positionHistory,
        searchInfo.targetDepth,
        searchInfo.stop,
        movesToGo = searchInfo.movesToGo,
        increment = searchInfo.increment,
        timeLeft = searchInfo.timeLeft,
        moveTime = searchInfo.moveTime,
        numThreads = searchInfo.numThreads,
        maxNodes = searchInfo.nodes
    ):
        doAssert pv.len >= 1
        bestMove = pv[0]

        # uci info
        printInfoString(
            iteration,
            value,
            nodes,
            passedTime,
            searchInfo.hashTable[].hashFull,
            pv.notation(searchInfo.position),
            beautiful = not searchInfo.uciCompatibleOutput
        )

        iteration += 1

    echo bestMove.bestMoveString(searchInfo.position)

type SearchResult = object
    move: Move
    value: Value
    pv: seq[Move]
    nodes: uint64
    passedTime: Duration

proc uciSearch*(searchInfo: SearchInfo) =

    if searchInfo.multiPv <= 0:
        return

    if searchInfo.multiPv == 1 and searchInfo.searchMoves.len == 0:
        searchInfo.uciSearchSinglePv()
        return

    var searchMoves = searchInfo.searchMoves
    if searchMoves.len == 0:
        for move in searchInfo.position.legalMoves():
            searchMoves.add move

    var iterators: seq[iterator (): SearchResult{.closure, gcsafe.}]

    for move in searchMoves:
        var newPositionHistory = searchInfo.positionHistory
        newPositionHistory.add searchInfo.position
        let newPosition = searchInfo.position.doMove(move)
        proc genIter(newPosition: Position, move: Move): iterator (): SearchResult{.closure, gcsafe.} =
            return iterator(): SearchResult{.closure, gcsafe.} =
                for (value, pv, nodes, passedTime) in iterativeTimeManagedSearch(
                    newPosition,
                    searchInfo.hashTable[],
                    newPositionHistory,
                    searchInfo.targetDepth - 1.Ply,
                    searchInfo.stop,
                    movesToGo = searchInfo.movesToGo,
                    increment = searchInfo.increment,
                    timeLeft = searchInfo.timeLeft,
                    moveTime = searchInfo.moveTime,
                    numThreads = searchInfo.numThreads,
                    maxNodes = searchInfo.nodes
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
                echo bestMove.bestMoveString(searchInfo.position)
                return

        searchResults.sort do (x, y: auto) -> int: cmp(y.value, x.value)

        for i, searchResult in searchResults.pairs:
            if i+1 > searchInfo.multiPv:
                break
            printInfoString(
                iteration,
                searchResult.value,
                searchResult.nodes,
                searchResult.passedTime,
                searchInfo.hashTable[].hashFull,
                searchResult.pv.notation(searchInfo.position),
                beautiful = not searchInfo.uciCompatibleOutput,
                i+1,
            )

        doAssert searchResults.len > 0
        let bestPv = searchResults[0].pv
        doAssert bestPv.len >= 1
        bestMove = bestPv[0]

        iteration += 1

