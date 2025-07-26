import types, bitboard, utils, position, zobristBitmasks
import std/[strutils]
export types

type
  MoveType = enum
    notSomeMove
    normalMove
    captureMove
    castledMove
    enPassantMove
    normalPromotionKnightMove
    capturePromotionKnightMove
    normalPromotionBishopMove
    capturePromotionBishopMove
    normalPromotionRookMove
    capturePromotionRookMove
    normalPromotionQueenMove
    capturePromotionQueenMove

  Move* = distinct uint16
  # source: [0..5], target: [6..11], MoveFlag: [12..15]

func `==`*(a, b: Move): bool {.borrow.}

func getMoveType(
    captured = false, enPassant = false, castled = false, promoted = noPiece
): MoveType =
  if enPassant:
    assert captured and not castled and promoted == noPiece
    return enPassantMove
  if castled:
    assert not captured and not enPassant and promoted == noPiece
    return castledMove
  if captured:
    case promoted
    of knight:
      capturePromotionKnightMove
    of bishop:
      capturePromotionBishopMove
    of rook:
      capturePromotionRookMove
    of queen:
      capturePromotionQueenMove
    else:
      assert promoted == noPiece
      captureMove
  else:
    case promoted
    of knight:
      normalPromotionKnightMove
    of bishop:
      normalPromotionBishopMove
    of rook:
      normalPromotionRookMove
    of queen:
      normalPromotionQueenMove
    else:
      assert promoted == noPiece
      normalMove

func newMove*(
    source, target: Square,
    captured = false,
    enPassant = false,
    castled = false,
    promoted = noPiece,
): Move =
  let moveType = getMoveType(captured, enPassant, castled, promoted)

  assert source != noSquare
  assert target != noSquare
  assert source.uint16 in 0u16 .. 0b111111u16
  assert target.uint16 in 0u16 .. 0b111111u16
  assert moveType != notSomeMove
  assert moveType.uint16 in 0u16 .. 0b1111u16

  Move(source.uint16 or (target.uint16 shl 6) or (moveType.uint16 shl 12))

const noMove*: Move = Move(notSomeMove.uint16 shl 12)

func moveType(move: Move): MoveType =
  MoveType((move.uint16 shr 12) and 0b1111u16)

func source*(move: Move): Square =
  Square(move.uint16 and 0b111111u16)

func target*(move: Move): Square =
  Square((move.uint16 shr 6) and 0b111111u16)

func promoted*(move: Move): Piece =
  case move.moveType
  of normalPromotionKnightMove, capturePromotionKnightMove: knight
  of normalPromotionBishopMove, capturePromotionBishopMove: bishop
  of normalPromotionRookMove, capturePromotionRookMove: rook
  of normalPromotionQueenMove, capturePromotionQueenMove: queen
  else: noPiece

func isCapture*(move: Move): bool =
  move.moveType in [
    captureMove, capturePromotionKnightMove, capturePromotionBishopMove,
    capturePromotionRookMove, capturePromotionQueenMove,
  ]

func isTactical*(move: Move): bool =
  move.isCapture or move.promoted != noPiece

func isCastling*(move: Move): bool =
  move.moveType == castledMove

func isEnPassantCapture*(move: Move): bool =
  move.moveType == enPassantMove

func `$`*(move: Move): string =
  if move == noMove:
    return "0000"
  assert move.moveType != notSomeMove
  result = $move.source & $move.target
  if move.promoted != noPiece:
    result &= move.promoted.notation

func moved*(move: Move, position: Position): Piece =
  assert position.coloredPieceAt(move.source).color == position.us
  position.pieceAt(move.source)

func captured*(move: Move, position: Position): Piece =
  if move.isCastling:
    noPiece
  elif move.isEnPassantCapture:
    pawn
  elif move.isCapture:
    assert position.coloredPieceAt(move.target).color == position.enemy
    position.pieceAt(move.target)
  else:
    noPiece

func castlingSide*(move: Move, position: Position): CastlingSide =
  if move.target == position.rookSource[position.us][queenside]:
    return queenside
  kingside

func enPassantTargetSquare*(move: Move, position: Position): Square =
  template flipOrNot(sq: Square): auto =
    if position.us == white: sq else: sq.mirrorVertically

  if move.moved(position) == pawn and
      not empty(move.source.toBitboard and ranks(a2.flipOrNot())) and
        not empty(move.target.toBitboard and ranks(a4.flipOrNot())):
          toSquare(ranks(a3.flipOrNot()) and files(move.source))
  else:
    noSquare

func isPseudoLegal*(position: Position, move: Move): bool =
  if move == noMove:
    return false

  let
    target = move.target
    source = move.source
    moved = move.moved(position)
    captured = move.captured(position)
    promoted = move.promoted
    capturedEnPassant = move.isEnPassantCapture
    us = position.us
    enemy = position.enemy
    occupancy = position.occupancy

  if moved notin pawn .. king or source notin a1 .. h8 or target notin a1 .. h8:
    return false

  # check that moved is okay
  if empty(source.toBitboard and position[us] and position[moved]):
    return false

  # check that target is okay, but handle castle case extra
  if not empty(target.toBitboard and position[us]) and not move.isCastling:
    return false

  # check that captured is okay, but handle en passant case extra
  if captured != noPiece and
      empty(target.toBitboard and position[enemy] and position[captured]) and
      not capturedEnPassant:
    return false
  if captured == noPiece and not empty(target.toBitboard and position[enemy]):
    return false

  # handle the captured en passant case
  if capturedEnPassant:
    if not target.toBitboard.isSet(position.enPassantTarget):
      return false
    if not empty(target.toBitboard and occupancy):
      return false

  if (moved == bishop or moved == rook or moved == queen) and
      empty(target.toBitboard and moved.attackMask(source, occupancy)):
    return false

  if moved == pawn:
    if captured != noPiece and
        empty(target.toBitboard and attackMaskPawnCapture(source, us)):
      return false
    elif captured == noPiece:
      doAssert move.moveType != captureMove
      if target.toBitboard != attackMaskPawnQuiet(source, us):
        if not empty(occupancy and attackMaskPawnQuiet(source, us)):
          return false
        if empty(
          move.enPassantTargetSquare(position).toBitboard and attackMaskPawnQuiet(target, enemy) and
            attackMaskPawnQuiet(source, us)
        ):
          return false
      elif move.enPassantTargetSquare(position) != noSquare:
        return false

  if promoted != noPiece:
    if moved != pawn:
      return false
    if promoted notin knight .. queen:
      return false
    if empty(target.toBitboard and (ranks(a1) or ranks(a8))):
      return false

  if move.isCastling:
    let castlingSide = move.castlingSide(position)

    let
      kingSource = (position[us] and position[king]).toSquare
      rookSource = position.rookSource[us][castlingSide]

    if rookSource != target or
        not empty(
          blockSensitive(us, castlingSide, kingSource, rookSource) and occupancy
        ):
      return false

    for checkSquare in checkSensitive[us][castlingSide][kingSource]:
      if position.isAttacked(us, checkSquare):
        return false

  assert source != noSquare and target != noSquare and moved != noPiece
  true

func doMove*(position: Position, move: Move): Position =
  result = position
  assert result.zobristKeysAreOk
  assert result.isPseudoLegal(move), $position & ", " & $move
  let
    target = move.target
    source = move.source
    moved = move.moved(position)
    captured = move.captured(position)
    promoted = move.promoted
    enPassantTarget = move.enPassantTargetSquare(position)
    us = result.us
    enemy = result.enemy

  result.zobristKey ^= result.enPassantTarget.Key
  if enPassantTarget != noSquare:
    result.enPassantTarget = enPassantTarget
  else:
    result.enPassantTarget = noSquare
  result.zobristKey ^= result.enPassantTarget.Key

  if moved == king:
    result.zobristKey ^= rookSourceBitmasks[result.rookSource[us][queenside]]
    result.zobristKey ^= rookSourceBitmasks[result.rookSource[us][kingside]]
    result.rookSource[us] = [noSquare, noSquare]
    # We should xor by noSquare twice, but that's basically a no-op

  for side in queenside .. kingside:
    if result.rookSource[us][side] == source:
      result.zobristKey ^= rookSourceBitmasks[result.rookSource[us][side]]
      result.rookSource[us][side] = noSquare
      result.zobristKey ^= rookSourceBitmasks[noSquare]
    if result.rookSource[enemy][side] == target:
      result.zobristKey ^= rookSourceBitmasks[result.rookSource[enemy][side]]
      result.rookSource[enemy][side] = noSquare
      result.zobristKey ^= rookSourceBitmasks[noSquare]

  # en passant
  if move.isEnPassantCapture:
    result.removePiece(enemy, pawn, attackMaskPawnQuiet(target, enemy).toSquare)

  # removing captured piece
  elif captured != noPiece:
    result.removePiece(enemy, captured, target)

  # castling
  if move.isCastling:
    let
      rookSource = target
      kingSource = source
      castlingSide = move.castlingSide(position)
      rookTarget = rookTarget[us][castlingSide]
      kingTarget = kingTarget[us][castlingSide]

    result.removePiece(us, king, kingSource)
    result.removePiece(us, rook, rookSource)

    for (piece, source, target) in [
      (king, kingSource, kingTarget), (rook, rookSource, rookTarget)
    ]:
      result.addPiece(us, piece, target)

  # moving piece
  else:
    if promoted != noPiece:
      result.removePiece(us, moved, source)
      result.addPiece(us, promoted, target)
    else:
      result.movePiece(us, moved, source, target)

  result.halfmovesPlayed += 1
  result.halfmoveClock += 1
  if moved == pawn or captured != noPiece:
    result.halfmoveClock = 0

  result.us = result.enemy

  result.zobristKey ^= zobristSideToMoveBitmasks[white]
  result.zobristKey ^= zobristSideToMoveBitmasks[black]


  # debugEcho "########################"
  # debugEcho position
  # debugEcho "--------------"
  # debugEcho result
  # debugEcho move

  assert result.zobristKeysAreOk

func isLegal*(position: Position, move: Move): bool =
  if not position.isPseudoLegal(move):
    return false
  let newPosition = position.doMove(move)
  return not newPosition.checkCheck(position.us)
