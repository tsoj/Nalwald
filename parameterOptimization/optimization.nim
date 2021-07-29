import ../evalParameters
import evalParametersUtils
import gradient
import times
import strformat
import startingParameters
import dataUtils
import winningProbability
import terminal
import ../defaultParameters

proc optimize(
    start: EvalParametersFloat,
    data: seq[Entry],
    lr = 280.0,
    minLearningRate = 10.0,
    maxIterations = int.high,
    minTries = 20,
    discount = 0.9
): EvalParameters =

    echo "-------------------"
    optimizeK(getError = proc(): float = start.convert.error(data))

    var bestSolution: EvalParametersFloat = start

    echo "-------------------"

    var lr = lr
    var bestError = bestSolution.convert.error(data)
    echo "starting error: ", fmt"{bestError:>9.7f}", ", starting lr: ", lr

    var previousGradient: EvalParametersFloat 
    for j in 0..maxIterations:

        var gradient: EvalParametersFloat
        var currentSolution = bestSolution
        let bestSolutionConverted = bestSolution.convert
        var totalWeight: float = 0.0

        const numProgressBarPoints = 100

        eraseLine()
        stdout.write("[")
        for p in 1..numProgressBarPoints:
            stdout.write("-")
        stdout.write("]")
        setCursorXPos(1)
        stdout.flushFile

        var p = 0
        for entry in data:
            p += 1
            if p mod (data.len div numProgressBarPoints) == 0:
                stdout.write("#")
                stdout.flushFile
            
            totalWeight += entry.weight
            gradient.addGradient(bestSolutionConverted, entry.position, entry.outcome, weight = entry.weight)
        # smooth the gradient out over previous discounted gradients. Seems to help in optimizatin speed and the final
        # result is better
        gradient *= (1.0/totalWeight)
        gradient *= 1.0 - discount
        previousGradient *= discount
        gradient += previousGradient
        previousGradient = gradient

        gradient *= lr

        let oldBestError = bestError
        
        eraseLine()
        stdout.write("iteration: " & fmt"{j:>3}")
        stdout.flushFile

        var leftTries = minTries
        var successes = 0
        var tries = 0
        while leftTries > 0:

            currentSolution += gradient
            let error = currentSolution.convert.error(data)

            tries += 1                    
            if error < bestError:
                leftTries += 1
                successes += 1

                bestError = error
                bestSolution = currentSolution
            else:
                leftTries -= 1
            
            # print info
            eraseLine()
            let s = $successes & "/" & $tries
            stdout.write(
                "iteration: " & fmt"{j:>3}" & ", successes: " & fmt"{s:>9}" &
                ", error: " & fmt"{bestError:>9.7f}", ", lr: ", lr
            )
            stdout.flushFile
        
        stdout.write("\n")
        stdout.flushFile

        if oldBestError <= bestError and lr >= minLearningRate:
            lr /= 2.0

        if lr < minLearningRate:
            break
        
    let filename = "optimizationResult_" & now().format("yyyy-MM-dd-HH-mm-ss") & ".txt"
    echo "filename: ", filename
    writeFile(filename, $bestSolution.convert)
        
    return bestSolution.convert

#echo defaultEvalParameters.s

var data: seq[Entry]
data.loadData("quietSetZuri.epd", weight = 1.0)
# Elements in quietSetNalwald are weighed less, because it brings better results.
# quietSetZuri is probably of higher quality
data.loadData("quietSetNalwald.epd", weight = 0.6)

#let startingEvalParametersFloat = defaultEvalParameters.convert
let startingEvalParametersFloat = startingEvalParameters

discard startingEvalParametersFloat.optimize(data)

    


