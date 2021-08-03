import
    ../position,
    ../positionUtils,
    game,
    times,
    threadpool,
    os,
    psutil,
    tables,
    strutils

proc playGame(fen: string): (string, float) =
    var game = newGame(
        startingPosition = fen.toPosition,
        moveTime = initDuration(milliseconds = 80),
    )
    (fen, game.playGame(suppressOutput = true))

const maxLoadPercentageCPU = 60.0

proc labelPositions() =
    var alreadyLabeled = block:
        var r: Table[string, int8]
        let g = open("quietSetNalwald.epd")
        var line: string
        while g.readLine(line):
            if line == "":
                continue
            let words = line.splitWhitespace
            doAssert words.len == 7
            let fen = words[0] & " " & words[1] & " " & words[2] & " " & words[3] & " " & words[4] & " " & words[5]
            r[fen] = 1
        g.close
        r

    let f = open("unlabeledQuietSetNalwald.epd")
    let g = open("quietSetNalwald.epd", fmAppend)
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
        i += 1
        if i mod 1000 == 0:
            echo i
        if line in alreadyLabeled and alreadyLabeled[line] == 1:
            alreadyLabeled[line] = 0
            continue
        writeResults()
        while cpu_percent() >= maxLoadPercentageCPU:
            sleep(10)
        threadResults.add(spawn playGame(line))
        sleep(10)
    writeResults()

    f.close
    g.close

labelPositions()