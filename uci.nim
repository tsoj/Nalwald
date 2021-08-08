import
    types,
    position,
    positionUtils,
    hashTable,
    uciSearch,
    uciInfos,
    perft,
    see,
    evaluation,
    version,
    easteregg/easteregg,
    times,
    strutils,
    os,
    atomics,
    threadpool

const
    startposFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    megaByteToByte = 1_048_576
    defaultHashSizeMB = 4
    maxHashSizeMB = 1_048_576

type UciState = object
    position: Position
    history: seq[Position]
    hashTable: HashTable
    stopFlag: Atomic[bool]

proc uci() =
    echo "id name Nalwald " & version()
    echo "id author Jost Triller"
    echo "option name Hash type spin default ", defaultHashSizeMB, " min 1 max ", maxHashSizeMB
    echo "option name UCI_Chess960 type check default false"
    echo "uciok"

proc setOption(uciState: var UciState, params: seq[string]) =

    if params.len == 4 and
    params[0] == "name" and
    params[2] == "value":
        if params[1] == "Hash":
            let newHashSizeMB = params[3].parseInt
            if newHashSizeMB < 1 or newHashSizeMB > maxHashSizeMB:
                echo "Invalid value"
            else:
                uciState.hashTable.setSize(sizeInBytes = newHashSizeMB * megaByteToByte)
        elif params[1] == "UCI_Chess960":
            discard
        else:
            echo "Unknown option: ", params[1]
    else:
        echo "Unknown parameters"
    
func stop(uciState: var UciState) =
    uciState.stopFlag.store(true)

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

    var targetDepth = Ply.high
    var movesToGo: int16 = int16.high
    var increment = [white: DurationZero, black: DurationZero]
    var timeLeft = [white: initDuration(milliseconds = int64.high), black: initDuration(milliseconds = int64.high)]
    var moveTime = initDuration(milliseconds = int64.high)

    for i in countup(0, params.len - 2, 2):
        case params[i]:
        of "depth":
            targetDepth = params[i+1].parseInt.Ply
        of "movestogo":
            movesToGo = params[i+1].parseInt.int16
        of "winc":
            increment[white] = initDuration(milliseconds = params[i+1].parseInt)
        of "binc":
            increment[black] = initDuration(milliseconds = params[i+1].parseInt)
        of "wtime":
            timeLeft[white] = initDuration(milliseconds = params[i+1].parseInt)
        of "btime":
            timeLeft[black] = initDuration(milliseconds = params[i+1].parseInt)
        of "movetime":
            moveTime = initDuration(milliseconds = params[i+1].parseInt)
        else:
            echo "Unknown parameter: ", params[i]
            return
     
    if searchThreadResult.isReady:
        searchThreadResult = spawn uciSearch(
            position = uciState.position,
            hashTable = addr uciState.hashTable,
            positionHistory = uciState.history,
            targetDepth = targetDepth,
            stop = addr uciState.stopFlag,
            movesToGo = movesToGo,
            increment = increment,
            timeLeft = timeLeft,
            moveTime = moveTime
        )

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
        echo uciState.position.perft(params[0].parseInt, printMoveNodes = true)
    else:
        echo "Missing depth parameter"

proc uciLoop*() =
    echo "---------------- Nalwald ----------------"
    echo "       __,      o     n_n_n   ooooo    + "
    echo " o    /  o\\    ( )    \\   /    \\ /    \\ /"
    echo "( )   \\  \\_>   / \\    |   |    / \\    ( )"
    echo "|_|   /__\\    /___\\   /___\\   /___\\   /_\\"
    echo "------------ by Jost Triller ------------"
    var uciState = UciState(position: startposFen.toPosition)
    uciState.hashTable.setSize(sizeInBytes = defaultHashSizeMB * megaByteToByte)
    var searchThreadResult = FlowVar[bool]()
    while true:
        try:
            sleep(5)
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
            of "about":
                about()
            of "easteregg":
                run()
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
