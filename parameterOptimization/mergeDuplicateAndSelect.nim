
import std/
[
    tables,
    strutils,
    random,
    times,
    os
]

randomize(epochTime().int64 mod 500_000)

const
    readFilename = "quietPoolGamesNalwald7.epd"
    writeFilename = "quietSmallPoolGamesNalwald7.epd"
    approxMaxNumLines = 5_500_000

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

for fen, (count, sum) in table:
    if rand(table.len) <= approxMaxNumLines:
        g.writeLine(fen & " " & $(sum/count))

f.close
g.close

