
import std/
[
    tables,
    strutils,
    random,
    times
]

randomize(epochTime().int64 mod 500_000)

const
    readFilename = "poolGamesNalwald.epd"
    writeFilename = "smallPoolGamesNalwald.epd"
    approxMaxNumLines = 2_500_000

let f = open(readFilename)
let g = open(writeFilename, fmWrite)

var
    table: Table[string, tuple[count: float, sum: float]]
    line: string
while f.readLine(line):
    let words = line.splitWhitespace()
    doAssert words.len == 7
    let
        fen = words[0] & " " & words[1] & " " & words[2] & " " & words[3] & " " & words[4] & " " & words[5]
        outcome = words[6].parseFloat
    if fen in table:
        table[fen].count += 1
        table[fen].sum += outcome
    else:
        table[fen] = (count: 1.0, sum: outcome)
        
for fen, (count, sum) in table:
    if rand(table.len) <= approxMaxNumLines:
        g.writeLine(fen & " " & $(sum/count))

f.close
g.close
