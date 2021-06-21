import position
import strutils
import moveIterator
import times

func perft*(position: Position, depth: int, height: int = 0, testZobristKeys: static bool = true): uint64 =
    if depth == 0:
        return 1

    var nodes: uint64 = 0

    for move in position.moveIterator:
        var newPosition = position
        newPosition.doMove(move)
        when testZobristKeys:
            doAssert newPosition.zobristKey == newPosition.calculateZobristKey
        if not newPosition.inCheck(position.us, position.enemy):
            let n = newPosition.perft(depth - 1, height + 1, testZobristKeys)
            nodes += n
    nodes


type PerftData = object
    position: Position
    nodes: seq[uint64]

proc getPerftTestData(): seq[PerftData] =

    var lines: seq[string]
    var file: File
    if file.open("./perft_test.txt"):
        lines = newSeq[string](0)
        var line: string
        while file.readLine(line):
            if line.isEmptyOrWhitespace:
                continue
            lines.add(line)
        file.close
    else:
        lines = @[
            "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1,48,2039,97862,4085603,193690690",
            "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1,14,191,2812,43238,674624,11030083,178633661",
            "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1,6,264,9467,422333,15833292",
            "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8,44,1486,62379,2103487,89941194",
            "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10,46,2079,89890,3894594,164075551",
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -,20,400,8902,197281,4865609,119060324"
        ]

    for line in lines:
        var words = line.split(',')
        doAssert words.len >= 1
        result.add(PerftData(position: words[0].toPosition, nodes: newSeq[uint64](0)))
        for i in 1..<words.len:
            result[^1].nodes.add(words[i].parseBiggestUInt)


proc perftTest*(maxNodes = uint64.high, testZobristKeys: static bool = true) =

    let data = getPerftTestData()
    
    var totalPassedMilliseconds: int64 = 0
    var totalNumNodes: uint64 = 0
        
    for perftData in data:
        echo "---------------\nTesting ", perftData.position.fen
        for depth in 0..<perftData.nodes.len:
            if perftData.nodes[depth] > maxNodes:
                break

            let start = now()
            let perftResult = perftData.position.perft(depth + 1, testZobristKeys = testZobristKeys)
            let passedTime = now() - start
            totalPassedMilliseconds += passedTime.inMilliseconds
            totalNumNodes += perftResult

            echo perftResult, (if perftResult == perftData.nodes[depth]: " == " else: " != "), perftData.nodes[depth]
            doAssert perftResult == perftData.nodes[depth], "Failed perft test"

    echo "Passed time: ", totalPassedMilliseconds, " ms"
    echo "Counted nodes: ", totalNumNodes
    echo "Nodes per second: ", (1000 * totalNumNodes) div totalPassedMilliseconds.uint64, " nps"
    
    echo "Finished perft test successfully"

