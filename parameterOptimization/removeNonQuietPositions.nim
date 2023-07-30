import
    ../search,
    ../positionUtils,
    ../evaluation

import std/[
    os
]

const
    readFilename = "poolGamesNalwald6.epd"
    writeFilename = "quietPoolGamesNalwald6.epd"

doAssert fileExists readFilename
doAssert not fileExists writeFilename

let f = open(readFilename)
let g = open(writeFilename, fmWrite)

var line: string
var i = 0
while f.readLine(line):
    if line.len > 0 and line[^1] == 's':
        continue
    let position = line.toPosition(suppressWarnings = true)
    if position.material != position.materialQuiesce:
        continue
    if position.legalMoves.len == 0:
        continue
    if position.halfmoveClock >= 100:
        continue
    g.writeLine(line)
    i += 1
    if (i mod 10_000) == 0:
        echo i

g.close()
f.close()