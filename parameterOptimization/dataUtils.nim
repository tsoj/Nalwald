import 
    ../position,
    ../positionUtils,
    ../evalParameters,
    ../evaluation,
    winningProbability,
    error,
    strutils

type Entry* = object
    position*: Position
    outcome*: float32
    weight*: float32

proc loadData*(data: var seq[Entry], filename: string, weight: float32 = 1.0, maxLen = int.high, suppressOutput = false) =
    let f = open(filename)
    var line: string
    var numEntries = 0
    while f.readLine(line):
        let words = line.splitWhitespace()
        if words.len == 0 or words[0] == "LICENSE:":
            continue
        doAssert words.len >= 7
        numEntries += 1
        data.add(Entry(position: line.toPosition(suppressWarnings = true), outcome: words[6].parseFloat, weight: weight))
        if numEntries >= maxLen:
            break
    f.close()
    if not suppressOutput:
        debugEcho filename & ": ", numEntries, " entries", ", weight: ", numEntries.float32 * weight


func error*(evalParameters: EvalParameters, entry: Entry, k: float32): float32 =
    let estimate = entry.position.absoluteEvaluate(evalParameters).winningProbability(k)
    error(entry.outcome, estimate)*entry.weight

func error*(evalParameters: EvalParameters, data: openArray[Entry], k: float32): float32 =
    result = 0.0
    
    var summedWeight: float32 = 0.0
    for entry in data:
        result += evalParameters.error(entry, k)
        summedWeight += entry.weight
    result /= summedWeight
