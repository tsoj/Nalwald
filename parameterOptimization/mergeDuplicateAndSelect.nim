
import std/
[
    tables,
    strutils,
    random,
    times,
    os
]

randomize(epochTime().int64 mod 500_000)

doAssert commandLineParams().len == 3

let
    readFilename = commandLineParams()[0]#"quietPoolGamesNalwald7.epd"
    writeFilename = commandLineParams()[1]#"quietSmallPoolGamesNalwald7.epd"
    selectFactor = commandLineParams()[2].parseFloat

doAssert selectFactor in 0.0..1.0

doAssert fileExists readFilename
doAssert not fileExists writeFilename

let f = open(readFilename)
let g = open(writeFilename, fmWrite)

var
    table: Table[string, tuple[count: float, sum: float]]
    line: string
    numInputPositions = 0
while f.readLine(line):
    if line.isEmptyOrWhitespace:
        continue
    let words = line.splitWhitespace()
    doAssert words.len == 7
    let
        fen = words[0] & " " & words[1] & " " & words[2] & " " & words[3] & " 0 1"
        outcome = words[6].parseFloat
    if fen in table:
        table[fen].count += 1
        table[fen].sum += outcome
    else:
        table[fen] = (count: 1.0, sum: outcome)
    numInputPositions += 1

echo "Num input positions: ", numInputPositions
echo "Num unique positions: ", table.len

var numSelectedPositions = 0
for fen, (count, sum) in table:
    if rand(1.0) <= selectFactor:
        numSelectedPositions += 1
        g.writeLine(fen & " " & $(sum/count))

echo "Num selected positions: ", numSelectedPositions

f.close
g.close

