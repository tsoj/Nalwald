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

proc setOption(uciState: var UciState, params: openArray[string]) =
    assert params.len >= 1 and params[0] == "setoption"

    if params.len == 5 and
    params[1] == "name" and
    params[3] == "value":
        if params[2].toLowerAscii == "Hash".toLowerAscii:
            let newHashSizeMB = params[4].parseInt
            if newHashSizeMB < 1 or newHashSizeMB > maxHashSizeMB:
                echo "Invalid value"
            else:
                uciState.hashTable.setSize(sizeInBytes = newHashSizeMB * megaByteToByte)
        elif params[2].toLowerAscii == "UCI_Chess960".toLowerAscii:
            discard
        else:
            echo "Unknown option: ", params[2]
    else:
        echo "Unknown parameters"
    
func stop(uciState: var UciState) =
    uciState.stopFlag.store(true)

proc moves(uciState: var UciState, params: openArray[string]) =
    if params.len < 2:
        echo "Missing moves"
    uciState.history.setLen(0)
    for i in 1..<params.len:
        uciState.history.add(uciState.position)
        uciState.position.doMove(params[i].toMove(uciState.position))

proc setPosition(uciState: var UciState, params: openArray[string]) =
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

    uciState.moves(params[index..^1])

proc go(uciState: var UciState, params: openArray[string], searchThreadResult: var FlowVar[bool]) =
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

proc test(params: openArray[string]) =
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

proc perft(uciState: UciState, params: openArray[string]) =
    if params.len >= 2:
        echo uciState.position.perft(params[1].parseInt, printMoveNodes = true)
    else:
        echo "Missing depth parameter"

proc help(params: openArray[string]) =
    if params.len <= 1:
        echo "Possible commands:"
        echo "* uci"
        echo "* setoption"
        echo "* isready"
        echo "* position"
        echo "* go"
        echo "* stop"
        echo "* quit"
        echo "* ucinewgame"
        echo "* moves"
        echo "* print"
        echo "* printdebug"
        echo "* fen"
        echo "* perft"
        echo "* test"
        echo "* eval"
        echo "* about"
        echo "Use 'help <command>' to get info about a specific command"
    else:
        echo "---------------------------------"
        case params[1]:
        of "uci":
            echo(
                "Tells engine to use the uci (universal chess interface). ",
                "After receiving the uci command the engine will identify itself with the 'id' command ",
                "and send the 'option' commands to inform which settings the engine supports if any. ",
                "After that the engine will sent 'uciok' to acknowledge the uci mode."
            )
        of "setoption":
            echo "setoption name <id> [value <x>]"
            echo(
                "This can be used to change the internal setting <id> to ",
                "the value <x>. For a setting with the 'button' type no value is needed. ",
                "Some examples:"
            )
            echo "'setoption name Hash value 512'"
            echo "'setoption name UCI_Chess960 value true'"
        of "isready":
            echo "Sends a ping to the engine that will be shortly answered with 'readyok' if the engine is still alive."
        of "position":
            echo "position [fen <fenstring> | startpos] moves <move_1> ... <move_i>"
            echo(
                "Sets up the position described in fenstring on the internal board and ",
                "plays the moves <move_1> to <move_i> on the internal chess board. ",
                "To start from the start position the string 'startpos' must be sent instead of 'fen <fenstring>. ",
                "If this position is from a different game than ",
                "the last position sent to the engine, the command 'ucinewgame' should be sent inbetween."
            )
        of "go":
            echo "go [wtime|btime|winc|binc|movestogo|movetime|depth|infinite [<x>]]..."
            echo(
                "Starts calculating on the current position set up with the 'position' command. ",
                "There are a number of commands that can follow this command, all will be sent as arguments ",
                "of the same command. ",
                "If one command is not sent its value will not influence the search."
            )
            echo "* wtime <x>"
            echo "White has <x> msec left on the clock."
            echo "* btime <x>"
            echo "Black has <x> msec left on the clock."
            echo "* winc <x>"
            echo "White has <x> msec increment per move."
            echo "* binc <x>"
            echo "Black has <x> msec increment per move."
            echo "* movestogo <x>"
            echo "There are <x> moves to the next time control. If this is not sent sudden death is assumed."
            echo "* depth <x>"
            echo "Search to <x> plies only."
            echo "* movetime <x>"
            echo "Search for exactly <x> msec."
            echo "* infinite"
            echo "Search until the 'stop' or 'quit' command."
            echo "Example:"
            echo "'go depth 35 wtime 60000 btime 60000 winc 1000 binc 1000'"
            echo(
                "Starts a search to a maximum of depth 35 and assumes that the ",
                "time control is 1 min + 1 second per move."
            )
        of "stop":
            echo "Stops the calculation as soon as possible."
        of "quit":
            echo "Quits the program as soon as possible."
        of "ucinewgame":
            echo "This is sent to the engine when the next search should be assumed to be from a different game."
        of "moves":
            echo "moves <move_1> ... <move_i>"
            echo "Plays the moves <move_1> to <move_i> on the internal chess board."
        of "print":
            echo "Prints the current internal board."
        of "printdebug":
            echo "Prints the internal representation of the current board."
        of "fen":
            echo "Prints the FEN notation of the current internal board."    
        of "perft":
            echo "perft <x>"
            echo "Calculates the perft of the current position to depth <x>."
        of "test":
            echo "test [<x>|nozobrist|pseudo|onlytxt]..."
            echo(
                "Runs SEE and perft tests. ",
                "If a file 'perft_test.txt' exists then the positions from that file will be included."
            )
            echo "* <x>"
            echo "Run perft test only to a maximum of <x> nodes per position."
            echo "* nozobrist"
            echo "Don't do zobrist key tests."
            echo "* pseudo"
            echo "Do tests for the pseudo legality function."
            echo "* onlytxt"
            echo "Use only the positions given in 'perft_test.txt' and not the internal test positions."
            echo "Example:"
            echo "'test 100000 nozobrist onlytxt'"
            echo(
                "Runs perft only up to 100000 nodes per positions, doens't do zobrist key test and only ",
                "uses positions from 'perft_test.txt'."
            )
        of "eval":
            echo "Prints the static evaluation value for the current internal position."
        of "about":
            echo "Just some info about Nalwald. Also, feel free to take a look at my gitlab repos: gitlab.com/tsoj :)"
        else:
            echo "Unknown command: ", params[1]

proc about() =
    echo(
        "Nalwald is a Super GM level chess engine for classical and fischer random chess. It supports the UCI, ",
        "so it can be used in most chess GUIs (Nibbler, Cutechess, Arena, etc.).\n",
        "Nalwald is written in the programming language Nim, which is a compiled language with an intuitive and clean syntax.\n",
        "I started programming chess engines in 2016. After the 'Hello World', the natural first program, my first big project ",
        "was jht-chess, a chess playing program with an console GUI. I used C++ but it looked more like messy C. ",
        "In hindsight I would say that it is hard to write worse spaghetti code than I did then, but it played well enough ",
        "to win against amateur chess players. Since then I wrote multiple chess engine, ",
        "most in C++ (jht-chess, zebra-chess, jht-chess 2, squared-chess, Googleplex Starthinker) but also one in Rust (Hactar) ",
        "and now also in Nim. While my first engine could barely beat myself (and I am not a very good chess player, ",
        "and much less in 2016), today Nalwald probably could beat Magnus Carlsen.\n",
        "On this way, the chessprogamming.org wiki was of great help many times. ",
        "From there I got most ideas for search improvements (move ordering, transposition table, LMR, etc.). ",
        "During the development of Nalwald I also introduced some techniques ",
        "that I believe are novelties (king contextual PSTs, fail-high delta pruning, ",
        "futility reductions, hash result futility pruning).\n",
        "Anyway, have fun using Nalwald!"
    )

proc uciLoop*() =
    echo(
        "---------------- Nalwald ----------------\n",
        "       __,      o     n_n_n   ooooo    + \n",
        " o    /  o\\    ( )    \\   /    \\ /    \\ /\n",
        "( )   \\  \\_>   / \\    |   |    / \\    ( )\n",
        "|_|   /__\\    /___\\   /___\\   /___\\   /_\\\n",
        "---- Copyright (c) 2021 Jost Triller ----"
    )
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
        of "moves":
            uciState.moves(params)
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
        of "about":
            about()
        of "help":
            help(params)
        else:
            echo "Unknown command: ", params[0]
            echo "Use 'help'"

    discard ^searchThreadResult
