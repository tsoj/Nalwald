import position, types, bitboard, evalParameters, utils, pieceValues, positionUtils

import std/[algorithm, macros]

export pieceValues

func cp*(cp: int): Value {.inline.} =
  (pawn.value * cp.Value) div 100.Value

func toCp*(value: Value): int {.inline.} =
  (100 * value.int) div pawn.value.int

func material*(position: Position): Value =
  result = 0
  for piece in pawn .. king:
    result +=
      (position[piece] and position[position.us]).countSetBits.Value * piece.value
    result -=
      (position[piece] and position[position.enemy]).countSetBits.Value * piece.value

func absoluteMaterial*(position: Position): Value =
  result = position.material
  if position.us == black:
    result = -result

func colorConditionalMirrorVertically(x: Square or Bitboard, color: Color): auto =
  if color == black: x.mirrorVertically else: x

type
  Gradient* {.requiresInit.} = object
    gradient*: ptr EvalParametersFloat
    g*: float32
    gamePhaseFactor*: float32

  EvalValue[ValueType: float32 or Value] {.requiresInit.} = object
    params: ptr EvalParametersTemplate[ValueType]
    absoluteValue: ptr array[Phase, Value]

  EvalState = Gradient or EvalValue

macro getParameter(structName, parameter: untyped): untyped =
  let s = $structName.toStrLit & "." & $parameter.toStrLit
  parseExpr(s)

template addValue(evalState: EvalState, goodFor: static Color, parameter: untyped) =
  when evalState is Gradient:
    let f = (if goodFor == black: -1.0 else: 1.0) * evalState.g
    getParameter(evalState.gradient[][opening.int], parameter) +=
      f * evalState.gamePhaseFactor
    getParameter(evalState.gradient[][endgame.int], parameter) +=
      f * (1.0 - evalState.gamePhaseFactor)
  else:
    static:
      doAssert evalState is EvalValue
    for phase {.inject.} in Phase:
      var value = getParameter(evalState.params[][phase.int], parameter).Value
      when goodFor == black:
        value = -value
      evalState.absoluteValue[phase] += value

func evaluatePieceTypeFromWhitesPerspective(
    evalState: EvalState, position: Position, piece: static Piece
) {.inline.} =
  for pieceColor in (white, black).fields:
    for square in (position[piece] and position[pieceColor]):
      let piece =
        when piece == pawn:
          if position.isPassedPawn(pieceColor, square): noPiece else: pawn
        else:
          piece

      let square = square.colorConditionalMirrorVertically(pieceColor)
      evalState.addValue(goodFor = pieceColor, pst[piece][square])

func absoluteEvaluate*(position: Position, evalState: EvalState) {.inline.} =
  if position.halfmoveClock >= 100:
    return

  # evaluating pieces
  for piece in (pawn, knight, bishop, rook, queen, king).fields:
    evalState.evaluatePieceTypeFromWhitesPerspective(position, piece)

func absoluteEvaluate*[ValueType: float32 or Value](
    position: Position, params: EvalParametersTemplate[ValueType]
): Value {.inline.} =
  var value: array[Phase, Value]
  let evalValue = EvalValue[ValueType](params: addr params, absoluteValue: addr value)
  position.absoluteEvaluate(evalValue)

  result = position.gamePhase.interpolate(
    forOpening = value[opening], forEndgame = value[endgame]
  )

  doAssert result.abs < valueCheckmate

func absoluteEvaluate*(position: Position): Value =
  position.absoluteEvaluate(defaultEvalParameters)

func perspectiveEvaluate*(position: Position): Value =
  result = position.absoluteEvaluate
  if position.us == black:
    result = -result
