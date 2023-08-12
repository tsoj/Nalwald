import
    position,
    types,
    perft,
    searchUtils,
    hashTable,
    moveIterator,
    positionUtils,
    utils,
    timeManagedSearch,
    see

import std/[
    random,
    times,
    strutils,
    terminal
]


type TestPerftState = object
    randomMoves: array[10000, Move]
    hashTable: ptr HashTable
    killerTable: KillerTable
    historyTable: ptr HistoryTable
    randState = initRand(0)
    testPseudoLegality = false

func testPerft(position: Position, state: var TestPerftState, depth: Ply, height: Ply, previous: Move): uint64 =
    ## Returns number of nodes and also does a number of asserts on different systems
    
    if depth <= 0.Ply:
        return 1

    # Test for isPseudoLegal
    var claimedPseudoLegalMoves: seq[Move]
    if state.testPseudoLegality:
        for move in state.randomMoves:
            if position.isPseudoLegal move:
                claimedPseudoLegalMoves.add move

    let hashResult = state.hashTable[].get(position.zobristKey)

    var
        bestMove = noMove
        numLegalMoves = 0

    for move in position.treeSearchMoveIterator(hashResult.bestMove, state.historyTable[], state.killerTable.get(height), previous):

        # Test for isPseudoLegal
        doAssert position.isPseudoLegal(move)
        if state.testPseudoLegality:
            for claimedMove in claimedPseudoLegalMoves.mitems:
                if claimedMove == move:
                    claimedMove = noMove
            state.randomMoves[state.randState.rand(0..<state.randomMoves.len)] = move

        let newPosition = position.doMove(move)

        # Test zobrist key incremental calculation
        doAssert newPosition.zobristKey == newPosition.calculateZobristKey

        if not newPosition.inCheck(position.us):
            numLegalMoves += 1
            result += newPosition.testPerft(state, depth = depth - 1, height = height + 1, previous = move)

            if bestMove == noMove:
                bestMove = move
            elif state.randState.rand(1.0) < 0.1:
                bestMove = move

    # Test all the search utils
    let bestValue = if state.randState.rand(1.0) < 0.01:
        valueCheckmate * state.randState.rand(-1..1).Value
    else:
        state.randState.rand(-valueCheckmate.int64..valueCheckmate.int64).Value
    
    let
        nodeTypeRandValue = state.randState.rand(1.0)
        nodeType = if nodeTypeRandValue < 0.45:
            allNode
        elif nodeTypeRandValue < 0.9:
            cutNode
        else:
            pvNode

    if numLegalMoves > 0:
        doAssert bestMove != noMove
        state.hashTable[].add(position.zobristKey, nodeType, bestValue, depth, bestMove)
        state.historyTable[].update(bestMove, previous, position.us, depth, raisedAlpha = nodeType != allNode)
        if nodeType == cutNode:
            state.killerTable.update(height, bestMove)

    # Test for isPseudoLegal
    if state.testPseudoLegality:
        for claimedMove in claimedPseudoLegalMoves:
            doAssert claimedMove == noMove, "Move: " & $claimedMove & ", position: " & position.fen

type PerftData = object
    position: Position
    nodes: seq[uint64]

proc getPerftTestData(useInternal, useExternal: bool): seq[PerftData] =

    var lines = if useInternal:
        @[
            # classical positions
            "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w QKqk - 0 1,48,2039,97862,4085603,193690690",
            "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1,14,191,2812,43238,674624,11030083,178633661",
            "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w qk - 0 1,6,264,9467,422333,15833292",
            "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w QK - 1 8,44,1486,62379,2103487,89941194",
            "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10,46,2079,89890,3894594,164075551",
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w QKqk -,20,400,8902,197281,4865609,119060324",
            # Chess960 positions
            "rnbqkbrn/p1pp1pp1/4p3/7p/2p4P/2P5/PP1PPPP1/R1BQKBRN w QGqg - 0 9,17,445,9076,255098,5918310,174733195",
            "b1rkrbnq/1pp1pppp/2np4/p5N1/8/1P2P3/P1PP1PPP/BNRKRB1Q w CEce - 0 9,37,740,27073,581744,21156664,485803600",
            "nrknbrqb/3p1ppp/ppN1p3/8/6P1/8/PPPPPP1P/1RKNBRQB w BFbf - 0 9,32,526,17267,319836,10755190,220058991",
            "bbqrnnkr/1ppp1p1p/5p2/p5p1/P7/1P4P1/2PPPP1P/1BQRNNKR w DKdk - 0 9,20,322,7224,145818,3588435,82754650"
        ]
    else:
        @[]

    var file: File
    if useExternal and file.open("./perft_test.txt"):
        var line: string
        while file.readLine(line):
            if line.isEmptyOrWhitespace:
                continue
            lines.add(line)
        file.close

    for line in lines:
        var words = line.split(',')
        doAssert words.len >= 1
        result.add(PerftData(position: words[0].toPosition, nodes: newSeq[uint64](0)))
        for i in 1..<words.len:
            result[^1].nodes.add(words[i].parseBiggestUInt)


proc testSearchAndPerft(
    maxNodes = uint64.high,
    useInternal = true,
    useExternal = true
) =
    let
        data = getPerftTestData(useInternal = useInternal, useExternal = useExternal)
        start = now()
    
    var
        hashTable = newHashTable()
        historyTable = newHistoryTable()
        testPerftState = TestPerftState(
            hashTable: addr hashTable,
            historyTable: addr historyTable
        )

    hashTable.setSize megaByteToByte * 16


        
    for perftData in data:
        let position = perftData.position
        echo "---------------\nTesting ", position.fen
        echo "Perft test:"
        # perft test
        for depth in 1..perftData.nodes.len:
            let trueNumNodes = perftData.nodes[depth - 1]

            if trueNumNodes > maxNodes:
                break

            testPerftState.testPseudoLegality = trueNumNodes < 200_000

            let
                testPerftResult = position.testPerft(
                    testPerftState,
                    depth = depth.Ply,
                    height = 0.Ply,
                    previous = noMove
                )
                perftResult = position.perft(depth.Ply)

            echo testPerftResult, (if testPerftResult == trueNumNodes: " == " else: " != "), trueNumNodes
            doAssert testPerftResult == trueNumNodes, "Failed perft test"
            doAssert perftResult == testPerftResult, "Failed fast perft test"

        # testing real search
        echo "Search test:"
        hashTable.clear()
        let searchResult = position.timeManagedSearch(
            hashTable, requireRootPv = true, moveTime = initDuration(seconds = 2)
        )
        doAssert searchResult.len > 0
        doAssert searchResult[0].value in -valueCheckmate..valueCheckmate
        doAssert searchResult[0].pv.len > 0
        echo "Value: ", searchResult[0].value, ", pv: ", searchResult[0].pv.notation(position)

    echo "---------------\nPassed time: ", now() - start   
    echo "Finished search/perft test successfully"

proc runTests*(
    maxNodes = uint64.high,
    useInternal = true,
    useExternal = true
) =
    doAssert "QQQQQQBk/Q6B/Q6Q/Q6Q/Q6Q/Q6Q/Q6Q/KQQQQQQQ w - - 0 1".toPosition.legalMoves.len == 265

    echo "---------------"
    styledEcho styleBright, "SEE test:"
    seeTest()

    echo "---------------"
    styledEcho styleBright, "Search and perft test:"
    testSearchAndPerft(
        maxNodes = maxNodes,
        useInternal = useInternal,
        useExternal = useExternal
    )

    echo "---------------"
    styledEcho styleBright, fgGreen, "Finished all tests successfully"


when isMainModule:
    runTests()