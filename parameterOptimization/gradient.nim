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
    position: Position, outcome: float
) =
    let currentValue = position.absoluteEvaluate(currentSolution)
    var currentGradient = Gradient(
        gamePhaseFactor: position.gamePhase.interpolate(forOpening = 1.0, forEndgame = 0.0),
        g: errorDerivative(outcome, currentValue.winningProbability) * currentValue.winningProbabilityDerivative,
        evalParams: addr gradient
    )
    discard position.absoluteEvaluate(currentSolution, currentGradient)




