
import
    ../position,
    ../positionUtils

import std/[
    os,
    streams,
    strformat
]

doAssert commandLineParams().len == 1, "Need file as commandline argument"

let fileName = commandLineParams()[0]

doAssert fileExists fileName, "File should exist"

var inFileStream = newFileStream(fileName, fmRead)

var content: seq[(Position, float)]

while not inFileStream.atEnd:
    let
        position = inFileStream.readPosition
        value = inFileStream.readFloat64
    content.add (position, value)

for (position, value) in content[0..<min(5, content.len)]:
    echo "--------------"
    echo position
    echo value

echo "--------------"
echo "..."

if content.len > 10:
    for (position, value) in content[^5..^1]:
        echo "--------------"
        echo position
        echo value



echo content.len, " positions"