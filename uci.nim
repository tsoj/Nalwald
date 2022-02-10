import
    types,
    move,
    position,
    positionUtils,
    hashTable,
    uciSearch,
    uciInfos,
    perft,
    see,
    evaluation,
    version,
    times,
    strutils,
    strformat,
    atomics,
    threadpool,
    os

const
    startposFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    megaByteToByte = 1_048_576
    defaultHashSizeMB = 4
    maxHashSizeMB = 1_048_576
    defaultNumThreads = 1
    maxNumThreads = 512

type UciState = object
    position: Position
    history: seq[Position]
    hashTable: HashTable
    stopFlag: Atomic[bool]
    searchRunningFlag: Atomic[bool]
    numThreads: int
    multiPv: int

proc uci() =
    echo "id name Nalwald " & version()
    echo "id author Jost Triller"
    echo "option name Hash type spin default ", defaultHashSizeMB, " min 1 max ", maxHashSizeMB
    echo "option name Threads type spin default ", defaultNumThreads, " min 1 max ", maxNumThreads
    echo "option name MultiPV type spin default 1 min 1 max 1000"
    echo "option name UCI_Chess960 type check default false"
    echo "uciok"

proc setOption(uciState: var UciState, params: seq[string]) =

    if params.len == 4 and
    params[0] == "name" and
    params[2] == "value":
        case params[1].toLowerAscii:
        of "Hash".toLowerAscii:
            let newHashSizeMB = params[3].parseInt
            if newHashSizeMB < 1 or newHashSizeMB > maxHashSizeMB:
                echo "Invalid value"
            else:
                uciState.hashTable.setSize(sizeInBytes = newHashSizeMB * megaByteToByte)
        of "UCI_Chess960".toLowerAscii:
            discard
        of "Threads".toLowerAscii:
            let newNumThreads = params[3].parseInt
            if newNumThreads < 1 or newNumThreads > maxNumThreads:
                echo "Invalid value"
            else:
                uciState.numThreads = newNumThreads
        of "MultiPV".toLowerAscii:
            let newMultiPv = params[3].parseInt
            if newMultiPv < 1 or newMultiPv > 1000:
                echo "Invalid value"
            else:
                uciState.multiPv = newMultiPv
        else:
            echo "Unknown option: ", params[1]
    else:
        echo "Unknown parameters"
    
proc stop(uciState: var UciState) =
    while uciState.searchRunningFlag.load:
        uciState.stopFlag.store(true)
        sleep(1)

proc moves(uciState: var UciState, params: seq[string]) =
    if params.len < 1:
        echo "Missing moves"

    var history = uciState.history
    var position = uciState.position
    
    for i in 0..<params.len:
        history.add(position)
        position.doMove(params[i].toMove(position))

    uciState.history = history
    uciState.position = position


proc setPosition(uciState: var UciState, params: seq[string]) =

    var index = 0
    var fen: string
    if params.len >= 1 and params[0] == "startpos":
        fen = startposFen
        index = 1
    elif params.len >= 1 and params[0] == "fen":
        index = 1
        var numFenWords = 0
        while params.len > index and params[index] != "moves":
            if numFenWords < 6:
                numFenWords += 1
                fen &= " " & params[index]
            index += 1
    else:
        echo "Unknown parameters"
        return

    uciState.position = fen.toPosition

    uciState.history.setLen(0)

    if params.len > index and params[index] == "moves":
        index += 1
        uciState.moves(params[index..^1])

proc go(uciState: var UciState, params: seq[string], searchThreadResult: var FlowVar[bool]) =

    var searchInfo = SearchInfo(
        position: uciState.position,
        hashTable: addr uciState.hashTable,
        positionHistory: uciState.history,
        targetDepth: Ply.high,
        stop: addr uciState.stopFlag,
        movesToGo: int16.high,
        increment: [white: DurationZero, black: DurationZero],
        timeLeft: [white: initDuration(milliseconds = int64.high), black: initDuration(milliseconds = int64.high)],
        moveTime: initDuration(milliseconds = int64.high),
        multiPv: uciState.multiPv,
        searchMoves: newSeq[Move](0),
        numThreads: uciState.numThreads
    )

    for i in 0..<params.len:
        if i+1 < params.len:  
            case params[i]:
            of "depth":
                searchInfo.targetDepth = params[i+1].parseInt.Ply
            of "movestogo":
                searchInfo.movesToGo = params[i+1].parseInt.int16
            of "winc":
                searchInfo.increment[white] = initDuration(milliseconds = params[i+1].parseInt)
            of "binc":
                searchInfo.increment[black] = initDuration(milliseconds = params[i+1].parseInt)
            of "wtime":
                searchInfo.timeLeft[white] = initDuration(milliseconds = params[i+1].parseInt)
            of "btime":
                searchInfo.timeLeft[black] = initDuration(milliseconds = params[i+1].parseInt)
            of "movetime":
                searchInfo.moveTime = initDuration(milliseconds = params[i+1].parseInt)
            else:
                discard         
        try:
            let move = params[i].toMove(uciState.position)
            searchInfo.searchMoves.add move
        except: discard
     
    uciState.stop()
    discard ^searchThreadResult

    proc runSearch(searchInfo: SearchInfo, searchRunning: ptr Atomic[bool]): bool =
        searchRunning[].store(true)
        uciSearch(searchInfo)
        searchRunning[].store(false)

    searchThreadResult = spawn runSearch(searchInfo, addr uciState.searchRunningFlag)
    
    while not (uciState.searchRunningFlag.load or searchThreadResult.isReady):
        sleep(1)

func uciNewGame(uciState: var UciState) =
    uciState.hashTable.clear()

proc test(params: seq[string]) =
    seeTest()
    if params.len == 0:
        perftTest()
    else:
        let numNodes = try:
            params[0].parseInt.uint64
        except:
            uint64.high

        perftTest(
            numNodes,
            testPseudoLegality = "pseudo" in params,
            testZobristKeys = not ("nozobrist" in params),
            useInternal = not ("nointernal" in params),
            useExternal = not ("noexternal" in params)
        )

proc perft(uciState: UciState, params: seq[string]) =
    if params.len >= 1:
        if "fast" in params:
            let start = now()
            let nodes = uciState.position.fastPerft(params[0].parseInt)
            let s = (now() - start).inMilliseconds.float / 1000.0
            echo nodes, " nodes in ", fmt"{s:0.3f}", " seconds"
            echo (nodes.float / s).int, " nodes per second"
        else:
            echo uciState.position.perft(params[0].parseInt, printMoveNodes = true)
    else:
        echo "Missing depth parameter"
        

proc uciLoop*() =
    echo fmt"---------------- Nalwald ----------------"
    echo fmt"       __,      o     n_n_n   ooooo    + "
    echo fmt" o    // o\    ( )    \   /    \ /    \ /"
    echo fmt"( )   \  \_>   / \    |   |    / \    ( )"
    echo fmt"|_|   /__\    /___\   /___\   /___\   /_\"
    echo fmt"------------ by Jost Triller ------------"
    var uciState = UciState(
        position: startposFen.toPosition,
        hashtable: newHashTable(),
        numThreads: defaultNumThreads,
        multiPv: 1
    )
    uciState.searchRunningFlag.store(false)
    uciState.hashTable.setSize(sizeInBytes = defaultHashSizeMB * megaByteToByte)
    var searchThreadResult = FlowVar[bool]()
    while true:
        try:
            let command = readLine(stdin)
            let params = command.splitWhitespace()
            if params.len == 0 or params[0] == "":
                continue
            case params[0]
            of "uci":
                uci()
            of "setoption":
                uciState.setOption(params[1..^1])
            of "isready":
                echo "readyok"
            of "position":
                uciState.setPosition(params[1..^1])
            of "go":
                uciState.go(params[1..^1], searchThreadResult)
            of "stop":
                uciState.stop()
            of "quit":
                uciState.stop()
                break
            of "ucinewgame":
                uciState.uciNewGame()
            of "moves":
                uciState.moves(params[1..^1])
            of "print":
                echo uciState.position
            of "printdebug":
                echo uciState.position.debugString
            of "fen":
                echo uciState.position.fen
            of "perft":
                uciState.perft(params[1..^1])
            of "test":
                test(params[1..^1])
            of "eval":
                echo uciState.position.absoluteEvaluate, " centipawns"
            of "piecevalues":
                for p in pawn..queen:
                    echo $p, ": ", p.value.toCp, " cp (", p.value, ")"
            of "about":
                about(extra = params.len >= 1 and "extra" in params)
            of "help":
                help(params[1..^1])
            else:
                try:
                    uciState.moves(params)
                except:
                    echo "Unknown command: ", params[0]
                    echo "Use 'help'"
        except:
            echo "info string ", getCurrentExceptionMsg()


    discard ^searchThreadResult
