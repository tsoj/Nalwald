import
    types,
    position,
    positionUtils,
    hashTable,
    uciSearch,
    perft,
    see,
    evaluation,
    version,
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

# TODO: self play test using cute chess with error output and release flags

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
    assert params.len >= 1 and params[0] == "setoption"

    if params.len == 5 and
    params[1] == "name" and
    params[3] == "value":
        if params[2] == "Hash":
            let newHashSizeMB = params[4].parseInt
            if newHashSizeMB < 1 or newHashSizeMB > maxHashSizeMB:
                echo "Invalid value"
            else:
                uciState.hashTable.setSize(sizeInBytes = newHashSizeMB * megaByteToByte)
        elif params[2] == "UCI_Chess960":
            discard
        else:
            echo "Unknown option: ", params[2]
    else:
        echo "Unknown parameters"
    
func stop(uciState: var UciState) =
    uciState.stopFlag.store(true)
    
proc setPosition(uciState: var UciState, params: seq[string]) =
    assert params.len >= 1 and params[0] == "position"

    var index = 0
    var fen: string
    if params.len >= 2 and params[1] == "startpos":
        fen = startposFen
        index = 2
    elif params.len >= 2 and params[1] == "fen":
        index = 2
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

    if params.len > index:
        doAssert params[index] == "moves"
        for i in (index + 1)..<params.len:
            uciState.history.add(uciState.position)
            uciState.position.doMove(params[i].toMove(uciState.position))

proc go(uciState: var UciState, params: seq[string], searchThreadResult: var FlowVar[bool]) =
    assert params.len >= 1 and params[0] == "go"

    var targetDepth = Ply.high
    var movesToGo: int16 = int16.high
    var increment = [white: DurationZero, black: DurationZero]
    var timeLeft = [white: initDuration(milliseconds = int64.high), black: initDuration(milliseconds = int64.high)]
    var moveTime = initDuration(milliseconds = int64.high)

    for i in countup(1, params.len - 2, 2):
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
    if params.len == 1:
        perftTest()
    else:
        let numNodes = try:
            params[1].parseInt.uint64
        except:
            uint64.high

        perftTest(
            numNodes,
            testPseudoLegality = "pseudo" in params,
            testZobristKeys = not ("nozobrist" in params),
            useAllFENs = not ("onlytxt" in params)
        )

proc perft(uciState: UciState, params: seq[string]) =
    if params.len >= 2:
        echo uciState.position.perft(params[1].parseInt, printMoveNodes = true)
    else:
        echo "Missing depth parameter"

proc about() =
    echo(
        "-----------------------------------------\n",
        "Nalwald ", version(), "\n",
        "Compiled at ", compileDate(), "\n",
        "(c) 2016-", compileYear() , " by Jost Triller\n",
        "\n",
        "Nalwald is a Super GM level chess engine\n",
        "for classical and fischer random chess.\n",
        "It supports the UCI, so it can be used in\n",
        "most chess GUIs (e.g. Cutechess, Arena).\n",
        "Nalwald is written in the programming\n",
        "language Nim, which is a compiled\n",
        "language with an intuitive and clean\n",
        "syntax.\n",
        "I started programming in 2016. After the\n",
        "well-known 'Hello World' program, my\n",
        "first big project was jht-chess, a chess\n",
        "playing program with an console GUI. I\n",
        "used C++ but it looked more like messy C.\n",
        "In hindsight I would say that it is hard\n",
        "to write worse spaghetti code than I did\n",
        "then, but it played well enough to win\n",
        "against amateur chess players. Since then\n",
        "I wrote multiple chess engine, most in\n",
        "C++ (jht-chess, zebra-chess, jht-chess 2,\n",
        "squared-chess, Googleplex Starthinker)\n",
        "but also one in Rust (Hactar) and now\n",
        "also in Nim. While my first engine could\n",
        "barely beat me (and I am not a very\n",
        "good chess player, and much less in\n",
        "2016), today maybe Nalwald could even\n",
        "beat Magnus Carlsen.\n",
        "On this way from a at best mediocre chess\n",
        "program to a chess engine that could win\n",
        "against the best human players, the\n",
        "chessprogamming.org wiki was of great\n",
        "help many times. From there I got most\n",
        "ideas for search improvements (move\n",
        "ordering, transposition table, LMR, etc.).\n",
        "During the development of Nalwald I also\n",
        "introduced some techniques that I believe\n",
        "are novelties (king contextual PSTs,\n",
        "fail-high delta pruning, futility\n",
        "reductions, hash result futility pruning).\n",
        "Anyway, have fun using Nalwald!\n",
        "-----------------------------------------"
    )


proc uciLoop*() =
    echo "---------------- Nalwald ----------------"
    echo "       __,      o     n_n_n   ooooo    + "
    echo " o    /  o\\    ( )    \\   /    \\ /    \\ /"
    echo "( )   \\  \\_>   / \\    |   |    / \\    ( )"
    echo "|_|   /__\\    /___\\   /___\\   /___\\   /_\\"
    echo "---- Copyright (c) 2021 Jost Triller ----"
    var uciState = UciState(position: startposFen.toPosition)
    uciState.hashTable.setSize(sizeInBytes = defaultHashSizeMB * megaByteToByte)
    var searchThreadResult = FlowVar[bool]()
    while true:
        sleep(5)
        let command = readLine(stdin)
        let params = command.splitWhitespace()
        if params.len == 0 or params[0] == "":
            continue
        case params[0]
        of "uci":
            uci()
        of "setoption":
            uciState.setOption(params)
        of "isready":
            echo "readyok"
        of "position":
            uciState.setPosition(params)
        of "go":
            uciState.go(params, searchThreadResult)
        of "stop":
            uciState.stop()
        of "quit":
            uciState.stop()
            break
        of "ucinewgame":
            uciState.uciNewGame()
        of "print":
            echo uciState.position
        of "printdebug":
            echo uciState.position.debugString
        of "fen":
            echo uciState.position.fen
        of "perft":
            uciState.perft(params)
        of "test":
            test(params)
        of "eval":
            echo uciState.position.absoluteEvaluate, " centipawns"
        of "flip":
            uciState.position = uciState.position.flipColors()
        of "about":
            about()

        else:
            if params[0] != "help": echo "Unknown command: ", params[0]
            echo "Possible commands:"
            echo "* uci"
            echo "* setoption"
            echo "* isready"
            echo "* position"
            echo "* go"
            echo "* stop"
            echo "* quit"
            echo "* ucinewgame"
            echo "* print"
            echo "* printdebug"
            echo "* fen"
            echo "* perft"
            echo "* test"
            echo "* eval"
            echo "* flip"

    discard ^searchThreadResult
