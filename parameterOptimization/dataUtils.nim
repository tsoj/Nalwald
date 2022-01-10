import 
    ../position,
    ../positionUtils,
    ../evalParameters,
    ../evaluation,
    ../types,
    winningProbability,
    error,
    strutils

type Entry* = object
    position*: Position
    outcome*: Float
    weight*: Float

proc loadData*(data: var seq[Entry], filename: string, weight: Float = 1.0, maxLen = int.high, suppressOutput = false) =
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
        debugEcho filename & ": ", numEntries, " entries", ", weight: ", numEntries.Float * weight


func error*(evalParameters: EvalParameters, entry: Entry, k: Float): Float =
    let estimate = entry.position.absoluteEvaluate(evalParameters).winningProbability(k)
    error(entry.outcome, estimate)*entry.weight

func error*(evalParameters: EvalParameters, data: openArray[Entry], k: Float): Float =
    result = 0.0
    
    var summedWeight: Float = 0.0
    for entry in data:
        result += evalParameters.error(entry, k)
        summedWeight += entry.weight
    result /= summedWeight
