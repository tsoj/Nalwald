import nimchess

import types, evalparams

import std/[times, strformat, random, math, os, macros]

type
  Gradient* {.requiresInit.} = object
    gradient*: ptr EvalParameters
    g*: float32
    gamePhaseFactor*: float32

  EvalValue {.requiresInit.} = object
    params: ptr EvalParameters
    absoluteValue: ptr float32

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
    evalState.absoluteValue[phase] += value

func eval*(pos: Position): Value =
  result = 0
  for piece in pawn .. king:
    for square in pos[piece, pos.us]:
      result +=
        defaultEvalParameters.psqt[piece][
          if pos.us == white: square else: square.mirrorVertically
        ]
    for square in pos[piece, pos.enemy]:
      result -=
        defaultEvalParameters.psqt[piece][
          if pos.enemy == white: square else: square.mirrorVertically
        ]
