import nimchess

import types, evalparams

import std/[times, strformat, random, math, os, macros]

func winningProbability*(x: float, k: float = 1.0): float =
  1.0 / (1.0 + exp(-(k * x)))

func winningProbabilityDerivative*(x: float, k: float = 1.0): float =
  let p = winningProbability(x, k)
  k * p * (1.0 - p)

func error*(outcome, estimate: float): float =
  (outcome - estimate) ^ 2

func errorDerivative*(outcome, estimate: float): float =
  2.0 * (outcome - estimate)

type
  Gradient* {.requiresInit.} = object
    gradient*: ptr EvalParameters
    g*: float32

  EvalValue {.requiresInit.} = object
    params: ptr EvalParameters
    whitePerspectiveScore: ptr float32

  EvalState = Gradient or EvalValue

# Piece square tables from white's perspective.
# For black, squares are transformed using mirrorVertically.
# Material value is included directly in each entry.

macro getParameter(structName, parameter: untyped): untyped =
  let s = $structName.toStrLit & "." & $parameter.toStrLit
  parseExpr(s)

template addValue(evalState: EvalState, parameter: untyped) =
  when evalState is Gradient:
    getParameter(evalState.gradient[], parameter) += evalState.g
  else:
    static:
      doAssert evalState is EvalValue
    var value = getParameter(evalState.params[], parameter)
    evalState.whitePerspectiveScore[] += value

func evalForWhite(pos: Position, evalState: EvalState) =
  assert pos.us == white, "White must be the player to move"
  
  for piece in pawn .. king:
    for square in pos[piece, black]:
      evalState.addValue psqt[black][piece][square.mirrorVertically]
    for square in pos[piece, white]:
      evalState.addValue psqt[white][piece][square]


func evalForWhite(pos: Position, params: EvalParameters): Value =
  assert pos.us == white, "White must be the player to move"

  result = 0
  let evalValue = EvalValue(params: addr params, whitePerspectiveScore: addr result)
  pos.evalForWhite(evalValue)
      
func eval*(pos: Position): Value =
  let pos = if pos.us == black: pos.mirrorVertically else: pos
  pos.evalForWhite(defaultEvalParameters)



func addGradient*(
    params: var EvalParameters, lr: float, position: Position, outcome: float
) =
  let currentValue = position.evalForWhite(params)
  var currentGradient = Gradient(
    g:
      errorDerivative(outcome, currentValue.winningProbability) *
      currentValue.winningProbabilityDerivative * lr,
    gradient: addr params,
  )
  position.evalForWhite(currentGradient)
