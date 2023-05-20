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
    algorithm,
    sugar,
    random
]

func printInfoString(
    iteration: int,
    value: Value,
    nodes: uint64,
    pv: string,
    time: Duration,
    hashFull: int,
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

func printInfoString(
    iteration: int,
    position: Position,
    pvList: seq[Pv],
    nodes: uint64,
    time: Duration,
    hashFull: int,
    beautiful: bool
) =
    doAssert pvList.isSorted((x, y) => cmp(x.value, y.value), Descending)

    for i, pv in pvList:
        printInfoString(
            iteration = iteration,
            value = pv.value,
            pv = pv.pv.notation(position),
            nodes = nodes,
            time = time,
            hashFull = hashFull,
            beautiful = beautiful,
            multiPvIndex = if pvList.len > 1: i + 1 else: -1
        )

proc bestMoveString(move: Move, position: Position): string =

    # king's gambit
    var r = initRand(epochTime().int64)
    if r.rand(1.0) < 0.5:
        if "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1".toPosition == position:
            return "e2e4"
        if "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2".toPosition == position:
            return "f2f4"

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

proc uciSearch*(searchInfo: SearchInfo) =

    doAssert searchInfo.multiPv > 0

    var
        bestMove = noMove
        iteration = 0

    for (pvList, nodes, passedTime) in searchInfo.position.iterativeTimeManagedSearch(
        searchInfo.hashTable[],
        searchInfo.positionHistory,
        searchInfo.targetDepth,
        searchInfo.stop,
        movesToGo = searchInfo.movesToGo,
        increment = searchInfo.increment,
        timeLeft = searchInfo.timeLeft,
        moveTime = searchInfo.moveTime,
        numThreads = searchInfo.numThreads,
        maxNodes = searchInfo.nodes,
        multiPv = searchInfo.multiPv,
        searchMoves = searchInfo.searchMoves
    ):
        let pvList = pvList.sorted((x, y) => cmp(x.value, y.value), Descending)
        doAssert pvList.len >= 1
        doAssert pvList[0].pv.len >= 1
        bestMove = pvList[0].pv[0]

        # uci info
        printInfoString(
            iteration = iteration,
            position = searchInfo.position,
            pvList = pvList,
            nodes = nodes,
            time = passedTime,
            hashFull = searchInfo.hashTable[].hashFull,
            beautiful = not searchInfo.uciCompatibleOutput
        )

        iteration += 1

    echo bestMove.bestMoveString(searchInfo.position)

