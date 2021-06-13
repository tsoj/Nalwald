import search
import position
import strutils
import types

let f = open("CCRL4040.epd")
var line: string

let o = open("CCRL4040_quiet.epd", fmWrite)
var i = 0
while f.readLine(line):
    if line == "" or line[0] == 'x':
        continue
    try:
        let words = line.splitWhitespace
        if words[7].parseInt < 3000:
            continue

        let position = line.toPosition(suppressWarnings = true)
        
        if position.inCheck(us = position.us, enemy = position.enemy):
            continue
        
        let quiesce = position.absoluteQuiesce
        if quiesce != position.absoluteMaterial or abs(quiesce) >= values[king]:
            continue

        let outcome = if words[6] == "1/2-1/2":
            "0.500"
        elif words[6] == "0-1":
            "0.000"
        else:
            "1.000"

        o.writeLine(position.fen & " " & outcome)
        i += 1
    except:
        echo "ERROR: ", line

f.close()
o.close()
    
echo "line: ", i

