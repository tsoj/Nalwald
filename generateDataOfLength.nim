import random
import strutils

const numFens = 3_000_000

let outputFile = open("combined_quiet_" & $numFens & ".epd", fmWrite)

var i = 0

let zuriFile = open("zuri_quiet.epd")
var line: string
while zuriFile.readLine(line):
    if i >= numFens:
        break
    i += 1
    outputFile.writeLine(line & " \"zuri\"")

if i < numFens:
    echo "loading ..."
    let ccrlStrings = readFile("CCRL4040_quiet.epd").splitLines
    echo "loaded\nshuffling ..."
    var indices: seq[int]
    for i in 0..<ccrlStrings.len:
        indices.add(i)
    indices.shuffle
    echo "shuffled"
    var index = 0
    while i < numFens and index < indices.len:
        outputFile.writeLine(ccrlStrings[indices[index]] & " \"CCRL\"")
        index += 1
        if i mod 100000 == 0:
            echo i
        i += 1
    