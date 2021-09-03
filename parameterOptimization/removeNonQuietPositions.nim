import
    ../search,
    ../position,
    ../positionUtils,
    ../evaluation,
    ../movegen

let f = open("unlabeledNonQuietSetNalwald.epd")
let g = open("unlabeledQuietSetNalwald.epd", fmWrite)
var line: string
var i = 0
while f.readLine(line):
    if line.len > 0 and line[^1] == 's':
        continue
    let position = line.toPosition
    if position.material != position.materialQuiesce:
        continue
    if position.legalMoves.len == 0:
        continue
    g.writeLine(position.fen)
    i += 1
    if (i mod 1000) == 0:
        echo i

g.close()
f.close()