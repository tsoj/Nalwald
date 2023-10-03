
import
    ../position,
    ../positionUtils

import std/[
    os,
    streams,
    strformat
]


var inFileStream = newFileStream("trainingSet.bin", fmRead)

while not inFileStream.atEnd:
    let
        position = inFileStream.readPosition
        value = inFileStream.readFloat64
        
    echo "----------------------"
    echo position
    echo value