import
    ../search,
    ../position,
    ../positionUtils,
    ../movegen

let f = open("unlabeledNonQuietSetNalwald.epd")
var line: string
while f.readLine(line):
    if line.len > 0 and line[^1] == 's':
        continue
    let position = line.toPosition
    if position.material != position.materialQuiesce:
        continue
    if position.legalMoves.len == 0:
        continue
    echo position.fen