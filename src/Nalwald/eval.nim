import nimchess

import types, evalparams, piecevalues

import std/[times, strformat, random, math, os, macros]

func winningProbability*(x: float, k: float = 1.0): float =
  1.0 / (1.0 + exp(-(k * x)))

func winningProbabilityDerivative(x: float, k: float = 1.0): float =
  let p = winningProbability(x, k)
  k * p * (1.0 - p)

func error*(outcome, estimate: float): float =
  (outcome - estimate) ^ 2

func errorDerivative(outcome, estimate: float): float =
  2.0 * (outcome - estimate)

func gamePhase(position: Position): float =
  func fullCount(pos: Position): float =
    result = 0.0
    for piece in [pawn, knight, bishop, rook, queen]:
      result += pos[piece].countSetBits.float * piece.value.float

  const maxGamePhase = classicalStartpos.fullCount

  position.fullCount / maxGamePhase

type
  Gradient {.requiresInit.} = object
    gradient: ptr EvalParameters
    g: Value
    gamePhaseFactor: Value

  EvalValue {.requiresInit.} = object
    params: ptr EvalParameters
    whitePerspectiveScore: ptr array[2, Value]

  EvalState = Gradient or EvalValue

# Piece square tables from white's perspective.
# For black, squares are transformed using mirrorVertically.
# Material value is included directly in each entry.

macro getParameter(structName, parameter: untyped): untyped =
  let s = $structName.toStrLit & "." & $parameter.toStrLit
  parseExpr(s)

template addValue(evalState: EvalState, parameter: untyped) =
  when evalState is Gradient:
    getParameter(evalState.gradient[][1], parameter) +=
      evalState.g * evalState.gamePhaseFactor
    getParameter(evalState.gradient[][0], parameter) +=
      evalState.g * (1.0 - evalState.gamePhaseFactor)
  else:
    static:
      doAssert evalState is EvalValue
    for phase {.inject.} in 0 .. 1:
      let value = getParameter(evalState.params[][phase], parameter)
      evalState.whitePerspectiveScore[phase] += value

func evalForWhite(pos: Position, evalState: EvalState) =
  assert pos.us == white, "White must be the player to move"

  for piece in pawn .. king:
    for square in pos[piece, black]:
      evalState.addValue psqt[black][piece][square.mirrorVertically]
    for square in pos[piece, white]:
      evalState.addValue psqt[white][piece][square]

func evalForWhite(pos: Position, params: EvalParameters): Value =
  assert pos.us == white, "White must be the player to move"

  var value = default(array[2, Value])
  let evalValue = EvalValue(params: addr params, whitePerspectiveScore: addr value)

  pos.evalForWhite(evalValue)

  let phase = pos.gamePhase
  value[1] * phase + value[0] * (1.0 - phase)

func eval*(pos: Position, params: EvalParameters): Value =
  let pos = if pos.us == black: pos.mirrorVertically else: pos
  pos.evalForWhite(params)

func eval*(pos: Position): Value =
  pos.eval(defaultEvalParameters)

func addGradient*(
    params: var EvalParameters, lr: float, position: Position, outcome: float
) =
  let currentValue = position.evalForWhite(params)
  var currentGradient = Gradient(
    gamePhaseFactor: position.gamePhase,
    g:
      errorDerivative(outcome, currentValue.winningProbability) *
      currentValue.winningProbabilityDerivative * lr,
    gradient: addr params,
  )
  position.evalForWhite(currentGradient)
