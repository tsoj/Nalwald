import ../types
import ../search
import ../position
import ../movegen
import strutils

let f = open("setPositions.epd")
var line: string
var i = 0
var j = 0
while f.readLine(line):
    j += 1
    if line.len > 0 and line[^1] == 's':
        continue
    let position = line.toPosition
    if position.material != position.materialQuiesce:
        continue
    if position.legalMoves.len == 0:
        continue
    echo position.fen
    i += 1

echo i, "/", j