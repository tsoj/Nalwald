import
    ../types,
    ../position,
    ../positionUtils,
    ../evaluation,
    game,
    times,
    random  

var numEvaluatedPositions: uint64 = 0
let g = open("unlabeledNonQuietSetNalwald.epd", fmWrite)

func evaluationWriteToFile(position: Position): Value =
    result = position.evaluate
    {.cast(noSideEffect).}:
        if rand(3_000_000) <= 140:
            numEvaluatedPositions += 1
            g.writeLine(position.fen)

let f = open("blitzTesting-4moves-openings.epd")
var line: string
var i = 0
while f.readLine(line):
    var game = newGame(
        startingPosition = line.toPosition,
        moveTime = initDuration(milliseconds = 20),
        evaluation = evaluationWriteToFile
    )
    try:
        discard game.playGame(suppressOutput = true)            
    except:
        echo "!!!!!"#TODO: fix exceptions
        echo getCurrentExceptionMsg()
        
    i += 1
    if (i mod 100) == 0:
        echo i, ", ", numEvaluatedPositions
    

f.close()
g.close()