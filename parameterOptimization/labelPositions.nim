import ../position
import times
import game
import ../types
import threadpool
import os
import psutil

proc playGame(fen: string): (string, float) =
    var game = newGame(
        startingPosition = fen.toPosition,
        moveTime = initDuration(milliseconds = 80),
    )
    (fen, game.playGame(suppressOutput = true))

proc labelPositions() =
    let f = open("unlabeledQuietSetNalwald.epd")
    let g = open("quietSetNalwald.epd", fmWrite)
    var line: string
    var i = 0

    var threadResults: seq[FlowVar[(string, float)]]
    template writeResults() =
        var newThreadResults: seq[FlowVar[(string, float)]]
        for tr in threadResults:
            if tr.isReady:
                let (fen, outcome) = ^tr
                g.writeLine(fen & " " & $outcome)
                g.flushFile
            else:
                newThreadResults.add(tr)
        threadResults = newThreadResults
        
    while f.readLine(line):
        echo playGame(line)
        # writeResults()
        # while cpu_percent() >= 50.0:
        #     sleep(10)
        # threadResults.add(spawn playGame(line))        
        i += 1
        echo i
        if i >= 10:
            break
        sleep(40)
    #writeResults()

    f.close
    g.close

labelPositions()