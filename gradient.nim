import evalParameters
import evaluation
import utils
import position
import types

func addGradient*(
    gradient: var EvalParametersFloat32,
    currentSolution: EvalParametersFloat32,
    position: Position, outcome: float32
) =
    var currentGradient: EvalParametersFloat32
    let currentValue = position.absoluteEvaluate(currentSolution.convert[:float32, Value], currentGradient)
    let g: float = 2.0*(outcome - currentValue.winningProbability) * currentValue.winningProbabilityDerivative
    currentGradient *= g
    gradient += currentGradient


