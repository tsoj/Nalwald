import
    ../types,
    ../position,
    ../positionUtils,
    ../evaluation,
    ../hashTable,
    ../rootSearch,
    game,
    random

import std/[atomics]

const 
    openingFilename = "smallPoolGamesNalwald.epd"#"blitzTesting-4moves-openings.epd"
    writeFilename = "leavesSmallPoolGamesNalwald.epd"#"unlabeledNonQuietSetNalwald.epd"
    playWholeGame = false
    maxNumNodes = 5_000
    approxNumOutPositionsPerSearch = 2.0

var numEvaluatedPositions: uint64 = 0
let g = open(writeFilename, fmWrite)

func evaluationWriteToFile(position: Position): Value =
    result = position.evaluate
    {.cast(noSideEffect).}:
        if rand(3_000_000.0) <= approxNumOutPositionsPerSearch * 6600000.0 / maxNumNodes.float:
            numEvaluatedPositions += 1
            g.writeLine(position.fen)

let f = open(openingFilename)
var
    line: string
    i = 0
    ht = newHashTable()
ht.setSize(maxNumNodes*2)

while f.readLine(line):
    let startingPosition = line.toPosition(suppressWarnings = true)

    if gameStatus(@[startingPosition]) != running:
        continue

    when playWholeGame:
        var game = newGame(
            startingPosition = startingPosition,
            maxNodes = maxNumNodes,
            evaluation = evaluationWriteToFile
        )
        try:
            discard game.playGame(suppressOutput = true)
        except CatchableError:
            echo getCurrentExceptionMsg()
   
    else:
        var stopFlag: Atomic[bool]
        stopFlag.store(false)
        for _ in iterativeDeepeningSearch(
            position = startingPosition,
            hashTable = ht,
            stop = addr stopFlag,
            maxNodes = maxNumNodes,
            evaluation = evaluationWriteToFile
        ):
            discard
        
    i += 1
    if (i mod 1000) == 0:
        echo i, ", ", numEvaluatedPositions
    

f.close()
g.close()