import random
import strutils

const numFens = 3_000_000

let ccrlFile = open("CCRL4040_quiet.epd")

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
    var ccrlStrings = readFile("CCRL4040_quiet.epd").splitLines
    ccrlStrings.shuffle
    var index = 0
    while i < numFens and index < ccrlStrings.len:
        outputFile.writeLine(ccrlStrings[index] & " \"CCRL\"")
        index += 1
        i += 1
    