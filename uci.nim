import position
import atomics
import threadpool
import types
import hashTable
import strutils
import uciSearch
import times
import perft
import see
import evaluation

const
    startposFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    mega = 1_000_000
    defaultHashSizeMB = 4
    maxHashSizeMB = 1048576

type UciState = object
    position: Position
    history: seq[Position]
    hashTable: HashTable
    stopFlag: Atomic[bool]
    changedHashTableSize: bool


proc uci() =
    echo "id name Nalwald 1.10"
    echo "id author Jost Triller"
    echo "option name Hash type spin default ", defaultHashSizeMB, " min 1 max ", maxHashSizeMB
    echo "uciok"

proc setOption(uciState: var UciState, params: seq[string]) =
    assert params.len >= 1 and params[0] == "setoption"

    if params.len == 5 and
    params[1] == "name" and
    params[2] == "Hash" and
    params[3] == "value":
        let newHashSizeMB = params[4].parseInt
        if newHashSizeMB < 1 or newHashSizeMB > maxHashSizeMB:
            echo "Invalid value"
        else:
            if uciState.changedHashTableSize:
                # TODO: fix memory leak
                echo "WARNING: changing size of hash table more than once may lead to memory leaks"
            uciState.changedHashTableSize = true
            uciState.hashTable.setSize(sizeInBytes = newHashSizeMB * mega)
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
        # TODO: fix crashes because of spawn
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

proc uciLoop*() =
    echo "---------------- Nalwald ----------------"
    echo "       __,      o     n_n_n   ooooo    + "
    echo " o    /  o\\    ( )    \\   /    \\ /    \\ /"
    echo "( )   \\  \\_>   / \\    |   |    / \\    ( )"
    echo "|_|   /__\\    /___\\   /___\\   /___\\   /_\\"
    echo "---- Copyright (c) 2021 Jost Triller ----"
    var uciState = UciState(position: startposFen.toPosition, changedHashTableSize: false)
    uciState.hashTable.setSize(sizeInBytes = defaultHashSizeMB * mega)
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
            of "test":
                seeTest()
                if params.len >= 2:
                    perftTest(params[1].parseInt.uint64)
                else:
                    perftTest()
            of "benchmark":
                perftTest(100_000_000, testZobristKeys = false)
            of "eval":
                echo uciState.position.absoluteEvaluate, " centipawns"

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
                echo "* test"
                echo "* benchmark"
                echo "* eval"
        except:
            echo "info string ", getCurrentExceptionMsg()

    discard ^searchThreadResult
