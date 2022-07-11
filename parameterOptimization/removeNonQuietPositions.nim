import
    ../search,
    ../positionUtils,
    ../evaluation

const
    readFilename = "unlabeledNonQuietSetNalwald.epd"#"unlabeledNonQuietSmallNalwaldCCRL4040.epd"
    writeFilename = "unlabeledQuietSetNalwald.epd"#"unlabeledQuietSmallNalwaldCCRL4040.epd"

let f = open(readFilename)
let g = open(writeFilename, fmWrite)

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