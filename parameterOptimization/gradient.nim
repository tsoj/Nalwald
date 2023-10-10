import
    ../evalParameters,
    ../evaluation,
    ../position,
    ../types,
    ../defaultParameters,
    winningProbability,
    error,
    ../bitboard,
    ../utils

func getActiveParameters*(position: Position): EvalParametersFloat =
    result = newEvalParametersFloat()
    var
        currentGradient = Gradient(
            gamePhaseFactor: 0.5,
            g: 1.0,
            evalParams: addr result
        )
    discard position.absoluteEvaluate(defaultEvalParameters, currentGradient)
    result = result.getMask(margin = 0.01)

func addGradient*(
    gradient: var EvalParametersFloat,
    currentSolution: EvalParameters,
    position: Position, outcome: float,
    k: float
) =
    let currentValue = position.absoluteEvaluate(currentSolution)
    var currentGradient = Gradient(
        gamePhaseFactor: position.gamePhase.interpolate(forOpening = 1.0, forEndgame = 0.0),
        g: errorDerivative(outcome, currentValue.winningProbability(k)) * currentValue.winningProbabilityDerivative(k),
        evalParams: addr gradient
    )
    discard position.absoluteEvaluate(currentSolution, currentGradient)




