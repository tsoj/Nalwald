import
    ../types,
    math,
    strformat

var k = 1.0
# TODO: fix all this, use utils.sigmoid
func winningProbability*(centipawn: Value): float =
    {.cast(noSideEffect).}: 1.0/(1.0 + pow(10.0, -((k*centipawn.float)/400.0)))

func winningProbabilityDerivative*(centipawn: Value): float =
    {.cast(noSideEffect).}:
        (ln(10.0) * pow(2.0, -2.0 - ((k*centipawn.float)/400.0)) * pow(5.0, -((k*centipawn.float)/400.0))) /
        pow(1.0 + pow(10.0, -((k*centipawn.float)/400.0)) , 2.0)

proc optimizeK*(getError: proc(): float, suppressOutput = false) =
    var change = 1.0
    var bestError = getError()
    var bestK = k
    while change.abs >= 0.000001:
        k += change
        let currentError = getError()
        if currentError < bestError:
            if not suppressOutput:
                debugEcho "k: ", fmt"{k:>9.7f}", ", error: ", fmt"{currentError:>9.7f}"
            bestError = currentError
            bestK = k
        else:
            change /= -2.0
            k = bestK
    k = bestK
    if not suppressOutput:
        debugEcho "optimized k: ", k



