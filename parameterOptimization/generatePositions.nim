import
    ../types,
    ../position,
    ../positionUtils,
    ../evaluation,
    game,
    times,
    random  

var numEvaluatedPositions: uint64 = 0
func evaluationWriteToFile(position: Position): Value =
    result = position.evaluate
    {.cast(noSideEffect).}:
        if rand(3_000_000) <= 140:
            numEvaluatedPositions += 1
            debugEcho position.fen

proc generatePositions() = 
    let f = open("blitzTesting-4moves-openings.epd")
    var line: string
    var i = 0
    while f.readLine(line):
        var game = newGame(
            startingPosition = line.toPosition,
            moveTime = initDuration(milliseconds = 20),
            evaluation = evaluationWriteToFile
        )
        discard game.playGame(suppressOutput = true)
        i += 1
    f.close()

generatePositions()