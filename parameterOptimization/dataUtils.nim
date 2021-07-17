import ../position
import ../evalParameters
import strutils
import ../evaluation
import winningProbability
import error

type Entry* = object
    position*: Position
    outcome*: float
    weight*: float

proc loadData*(data: var seq[Entry], filename: string, weight: float, suppressOutput = false) =
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
    f.close()
    if not suppressOutput:
        debugEcho filename & ": ", numEntries, " entries", ", weight: ", numEntries.float * weight


func error*(evalParameters: EvalParameters, entry: Entry): float =
    let estimate = entry.position.absoluteEvaluate(evalParameters).winningProbability
    error(entry.outcome, estimate)*entry.weight

func error*(evalParameters: EvalParameters, data: openArray[Entry]): float =
    result = 0.0
    
    var summedWeight: float = 0.0
    for entry in data:
        result += evalParameters.error(entry)
        summedWeight += entry.weight
    result /= summedWeight
