import
    ../evalParameters,
    gradient,
    dataUtils,
    calculatePieceValue

import std/[
    times,
    strformat,
    random,
    math
]

proc optimize(
    start: EvalParametersFloat,
    data: var seq[Entry],
    maxNumEpochs = 30,
    startLr = 10.0,
    finalLr = 0.05
): (EvalParametersFloat, float) =

    var solution = start

    echo "starting error: ", fmt"{solution.convert.error(data):>9.7f}", ", starting lr: ", startLr

    let lrDecay = pow(finalLr/startLr, 1.0/float(maxNumEpochs * data.len))
    doAssert startLr > finalLr, "Starting learning rate must be strictly bigger than the final learning rate"
    doAssert finalLr == startLr or lrDecay < 1.0, "lrDecay should be smaller than one if the learning rate should decrease"

    var lr = startLr

    for epoch in 1..maxNumEpochs:
        let startTime = now()
        data.shuffle

        for entry in data:
            solution.addGradient(lr, entry.position, entry.outcome)
            lr *= lrDecay

        let
            error = solution.convert.error(data[0..<min(data.len, 1_000_000)])
            passedTime = now() - startTime
        echo fmt"Epoch {epoch}, error: {error:>9.7f}, lr: {lr:.3f}, time: {passedTime.inSeconds} s"
    
    let finalError = solution.convert.error(data)
    echo fmt"Final error: {finalError:>9.7f}"
        
    return (solution, finalError)

let startTime = now()

var data: seq[Entry]
data.loadDataEpd "trainingSets/quietSetNalwald.epd"
data.loadDataEpd "trainingSets/quietSetCombinedCCRL4040.epd"
data.loadDataEpd "trainingSets/quietSmallPoolGamesNalwald.epd"
data.loadDataEpd "trainingSets/quietSetNalwald2.epd"
data.loadDataEpd "trainingSets/quietLeavesSmallPoolGamesNalwaldSearchLabeled.epd"
data.loadDataEpd "trainingSets/quietSmallPoolGamesNalwald2Labeled.epd"
data.loadDataEpd "trainingSets/gamesNalwald.epd"

data.loadDataBin "trainingSets/trainingSet_2023-10-03-18-29-44.bin"
data.loadDataBin "trainingSets/trainingSet_2023-10-03-18-30-48.bin"
data.loadDataBin "trainingSets/trainingSet_2023-10-03-23-14-51.bin"
data.loadDataBin "trainingSets/trainingSet_2023-10-03-23-35-01.bin"
data.loadDataBin "trainingSets/trainingSet_2023-10-04-00-47-53.bin"
data.loadDataBin "trainingSets/trainingSet_2023-10-06-17-43-01.bin"
data.loadDataBin "trainingSets/trainingSet_2023-12-22-16-08-28.bin"
data.loadDataBin "trainingSets/trainingSet_2023-12-22-16-15-24.bin"
data.loadDataBin "trainingSets/trainingSet_2023-12-22-16-16-28.bin"
data.loadDataBin "trainingSets/trainingSet_2023-12-22-19-19-13.bin"
data.loadDataBin "trainingSets/trainingSet_2023-12-24-02-31-35.bin"
data.loadDataBin "trainingSets/trainingSet_2023-12-28-11-23-21.bin"
data.shuffle

echo "Total number of entries: ", data.len

let (ep, finalError) = newEvalParametersFloat().optimize(data)

let
    timeString = now().format("yyyy-MM-dd-HH-mm-ss")
    fileName = fmt"optimizationResult_{timeString}_{finalError:>9.7f}.txt"

let fileContent = &"""
import evalParameters

const defaultEvalParameters* = {ep.convert.toSeq}.toEvalParameters

func value*(piece: Piece): Value =
    const table = [{ep.convert.pieceValuesAsString(data[0..<min(data.len, 10_000_000)])}king: valueCheckmate, noPiece: 0.Value]
    table[piece]
"""

writeFile(fileName, fileContent)
echo "filename: ", fileName

echo "Total time: ", now() - startTime
