import evalParameters
import evaluation
import utils

func addGradient(
    gradient: var EvalParametersFloat32,
    currentSolution: EvalParametersFloat32,
    position: Posiiton, outcome: float32
) =
    var currentGradient: EvalParametersFloat32
    let currentValue = position.absoluteEvaluate(currentSolution.convert[:float32, Value])
    let g: float = 2.0*(outcome - currentValue.winningProbability) * currentValue.winningProbabilityDerivative
    currentGradient *= g
    gradient += currentGradient
