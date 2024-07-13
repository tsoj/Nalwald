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

func mobility(
    evalState: EvalState,
    position: Position,
    piece: static Piece,
    us: static Color,
    attackMask: Bitboard,
) =
  let reachableSquares = (attackMask and not position[us]).countSetBits
  evalState.addValue(goodFor = us, bonusMobility[piece][reachableSquares])

func forkingMajorPieces(
    evalState: EvalState, position: Position, us: static Color, attackMask: Bitboard
) =
  if (attackMask and position[us.opposite] and (position[queen] or position[rook])).countSetBits >=
      2:
    evalState.addValue(goodFor = us, bonusPieceForkedMajorPieces)

func attackingPiece(
    evalState: EvalState,
    position: Position,
    piece: static Piece,
    us: static Color,
    attackMask: Bitboard,
) =
  static:
    doAssert piece in knight .. queen
  for attackedPiece in pawn .. king:
    if not empty(attackMask and position[us.opposite] and position[attackedPiece]):
      evalState.addValue(goodFor = us, bonusAttackingPiece[piece][attackedPiece])

func targetingKingArea(
    evalState: EvalState,
    position: Position,
    piece: static Piece,
    us: static Color,
    attackMask: Bitboard,
) =
  static:
    doAssert piece in bishop .. queen
  let enemy = us.opposite
  if not empty(
    attackMask and king.attackMask(position[king, enemy].toSquare, 0.Bitboard)
  ):
    evalState.addValue(goodFor = us, bonusTargetingKingArea[piece])

func evaluatePawn(
    evalState: EvalState, position: Position, square: Square, us: static Color
) =
  # passed pawn
  if position.isPassedPawn(us, square):
    # passed pawn can move forward
    let index = square.colorConditionalMirrorVertically(us).int div 8
    evalState.addValue(goodFor = us, bonusPassedPawnCanMove[index])

    # isolated pawn
    if empty(position[pawn] and position[us] and adjacentFiles[square]):
      evalState.addValue(goodFor = us, bonusIsolatedPawn)

    # has two neighbors
    elif not empty(position[us] and position[pawn] and rightFiles[square]) and
        not empty(position[us] and position[pawn] and leftFiles[square]):
      evalState.addValue(goodFor = us, bonusPawnHasTwoNeighbors)

func evaluateKnight(
    evalState: EvalState, position: Position, square: Square, us: static Color
) =

  let attackMask = knight.attackMask(square, position.occupancy)

  # mobility
  evalState.mobility(position, knight, us, attackMask)

  # forks
  evalState.forkingMajorPieces(position, us, attackMask)

  # attacking pieces
  evalState.attackingPiece(position, knight, us, attackMask)

  # attacking bishop, rook, or queen
  if not empty(
    attackMask and position[us.opposite] and
      (position[bishop] or position[rook] or position[queen])
  ):
    evalState.addValue(goodFor = us, bonusKnightAttackingPiece)

func evaluateBishop(
    evalState: EvalState, position: Position, square: Square, us: static Color
) =

  let attackMask = bishop.attackMask(square, position.occupancy)

  # mobility
  evalState.mobility(position, bishop, us, attackMask)

  # forks
  evalState.forkingMajorPieces(position, us, attackMask)

  # attacking pieces
  evalState.attackingPiece(position, bishop, us, attackMask)

  # targeting enemy king area
  evalState.targetingKingArea(position, bishop, us, attackMask)

  # both bishops
  if not empty(position[us] and position[bishop] and not square.toBitboard):
    evalState.addValue(goodFor = us, bonusBothBishops)

func evaluateRook(
    evalState: EvalState, position: Position, square: Square, us: static Color
) =
  let attackMask = rook.attackMask(square, position.occupancy)

  # mobility
  evalState.mobility(position, rook, us, attackMask)

  # attacking pieces
  evalState.attackingPiece(position, rook, us, attackMask)

  # targeting enemy king area
  evalState.targetingKingArea(position, rook, us, attackMask)

  # rook on open file
  if empty(files[square] and position[pawn]):
    evalState.addValue(goodFor = us, bonusRookOnOpenFile)

func evaluateQueen(
    evalState: EvalState, position: Position, square: Square, us: static Color
) =
  let attackMask = queen.attackMask(square, position.occupancy)

  # mobility
  evalState.mobility(position, queen, us, attackMask)

  # attacking pieces
  evalState.attackingPiece(position, queen, us, attackMask)

  # targeting enemy king area
  evalState.targetingKingArea(position, queen, us, attackMask)

func evaluateKing(
    evalState: EvalState, position: Position, square: Square, us: static Color
) =
  # kingsafety by pawn shielding
  let numPossibleQueenAttack =
    queen.attackMask(square, position[pawn] and position[us]).countSetBits
  evalState.addValue(goodFor = us, bonusKingSafety[numPossibleQueenAttack])

  # numbers of attackers near king
  let numNearAttackers = (position[us.opposite] and mask5x5[square]).countSetBits
  evalState.addValue(goodFor = us, bonusAttackersNearKing[numNearAttackers])

func evaluatePieceTypeFromWhitesPerspective(
    evalState: EvalState,
    position: Position,
    piece: static Piece,
    color: static Color,
    square: Square,
) {.inline.} =
  when piece == pawn:
    evalState.evaluatePawn(position, square, color)
  elif piece == knight:
    evalState.evaluateKnight(position, square, color)
  elif piece == bishop:
    evalState.evaluateBishop(position, square, color)
  elif piece == rook:
    evalState.evaluateRook(position, square, color)
  elif piece == queen:
    evalState.evaluateQueen(position, square, color)
  elif piece == king:
    evalState.evaluateKing(position, square, color)

  # pst
  let piece =
    when piece == pawn:
      if position.isPassedPawn(color, square): noPiece else: pawn
    else:
      piece

  let square = square.colorConditionalMirrorVertically(color)
  evalState.addValue(goodFor = color, pst[piece][square])

func evaluatePieceTypeFromWhitesPerspective(
    evalState: EvalState, position: Position, piece: static Piece
) {.inline.} =
  for pieceColor in (white, black).fields:
    for square in (position[piece] and position[pieceColor]):
      evalState.evaluatePieceTypeFromWhitesPerspective(
        position, piece, pieceColor, square
      )

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
