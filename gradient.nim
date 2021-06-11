import evalParameters
import evaluation
import utils
import position
import types

func addGradient*(
    gradient: var EvalParameters,
    currentSolution: EvalParameters,
    position: Position, outcome: float
) =
    var currentGradient: EvalParameters
    let currentValue = position.absoluteEvaluate(currentSolution, currentGradient)
    # debugEcho "-----------------"
    # debugEcho "outcome: ", outcome
    # debugEcho position
    # debugEcho currentGradient
    let g: float = 2.0*(outcome - currentValue.winningProbability) * currentValue.winningProbabilityDerivative
    currentGradient *= g
    gradient += currentGradient


