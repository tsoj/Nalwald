import ../positionUtils

const
    readFilename = "quietSmallPoolGamesNalwald2GameLabel.epd"
    writeFilename = "quietSmallPoolGamesNalwald2Unlabeled.epd"

let f = open(readFilename)
let g = open(writeFilename, fmWrite)

var line: string
var i = 0
while f.readLine(line):
    g.writeLine(line.toPosition(suppressWarnings = true).fen)
    i += 1
    if (i mod 10000) == 0:
        echo i

g.close()
f.close()