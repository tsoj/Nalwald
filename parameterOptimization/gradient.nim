import
    ../evalParameters,
    ../evaluation,
    ../position,
    ../types,
    winningProbability,
    error,
    ../bitboard,
    ../utils


func addGradient*(
    gradient: var EvalParametersFloat,
    currentSolution: EvalParameters,
    position: Position, outcome: float,
    k: float
) =
    for (position, outcome) in [
        (position, outcome),
        (position.mirrorHorizontally(skipZobristKey = true), outcome),
        (position.mirrorVertically(skipZobristKey = true), 1.0 - outcome),
        (position.rotate(skipZobristKey = true), 1.0 - outcome),
    ]:
        let currentValue = position.absoluteEvaluate(currentSolution)
        var currentGradient = Gradient(
            gamePhaseFactor: position.gamePhase.interpolate(forOpening = 1.0, forEndgame = 0.0),
            g: errorDerivative(outcome, currentValue.winningProbability(k)) * currentValue.winningProbabilityDerivative(k),
            evalParams: addr gradient
        )
        discard position.absoluteEvaluate(currentSolution, currentGradient)


