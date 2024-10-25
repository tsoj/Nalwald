import types, bitboard, move, zobristBitmasks, castling, utils

export types, bitboard, move

type Position* {.packed.} = object
  pieces*: array[pawn .. king, Bitboard]
  colors*: array[white .. black, Bitboard]
  enPassantTarget*: Bitboard
  rookSource*: array[white .. black, array[CastlingSide, Square]]
  zobristKey*: ZobristKey
  us*: Color
  halfmovesPlayed*: int
  halfmoveClock*: int

func enemy*(position: Position): Color =
  position.us.opposite

func `[]`*(position: Position, piece: Piece): Bitboard {.inline.} =
  position.pieces[piece]

func `[]`*(position: var Position, piece: Piece): var Bitboard {.inline.} =
  position.pieces[piece]

func `[]=`*(position: var Position, piece: Piece, bitboard: Bitboard) {.inline.} =
  position.pieces[piece] = bitboard

func `[]`*(position: Position, color: Color): Bitboard {.inline.} =
  position.colors[color]

func `[]`*(position: var Position, color: Color): var Bitboard {.inline.} =
  position.colors[color]

func `[]=`*(position: var Position, color: Color, bitboard: Bitboard) {.inline.} =
  position.colors[color] = bitboard

func `[]`*(position: Position, piece: Piece, color: Color): Bitboard {.inline.} =
  position[color] and position[piece]
func `[]`*(position: Position, color: Color, piece: Piece): Bitboard {.inline.} =
  position[color] and position[piece]

func addPiece*(
    position: var Position, color: Color, piece: Piece, target: Square
) {.inline.} =
  let bit = target.toBitboard
  position[piece] |= bit
  position[color] |= bit

func removePiece*(
    position: var Position, color: Color, piece: Piece, source: Square
) {.inline.} =
  let bit = not source.toBitboard
  position[piece] &= bit
  position[color] &= bit

func movePiece*(
    position: var Position, color: Color, piece: Piece, source, target: Square
) {.inline.} =
  position.removePiece(color, piece, source)
  position.addPiece(color, piece, target)

func castlingSide*(position: Position, move: Move): CastlingSide =
  if move.target == position.rookSource[position.us][queenside]:
    return queenside
  kingside

func occupancy*(position: Position): Bitboard =
  position[white] or position[black]

func attackers*(position: Position, attacker: Color, target: Square): Bitboard =
  let occupancy = position.occupancy
  (
    (bishop.attackMask(target, occupancy) and (position[bishop] or position[queen])) or
    (rook.attackMask(target, occupancy) and (position[rook] or position[queen])) or
    (knight.attackMask(target, occupancy) and position[knight]) or
    (king.attackMask(target, occupancy) and position[king]) or
    (attackMaskPawnCapture(target, attacker.opposite) and position[pawn])
  ) and position[attacker]

func isAttacked*(position: Position, us: Color, target: Square): bool =
  not empty position.attackers(us.opposite, target)

func isPseudoLegal*(position: Position, move: Move): bool =
  if move == noMove:
    return false

  let
    target = move.target
    source = move.source
    moved = move.moved
    captured = move.captured
    promoted = move.promoted
    enPassantTarget = move.enPassantTarget
    capturedEnPassant = move.capturedEnPassant
    us = position.us
    enemy = position.enemy
    occupancy = position.occupancy

  if moved notin pawn .. king or source notin a1 .. h8 or target notin a1 .. h8:
    return false

  # check that moved is okay
  if empty(source.toBitboard and position[us] and position[moved]):
    return false

  # check that target is okay, but handle castle case extra
  if not empty(target.toBitboard and position[us]) and not move.castled:
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
    if empty(target.toBitboard and position.enPassantTarget):
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
      if target.toBitboard != attackMaskPawnQuiet(source, us):
        if not empty(occupancy and attackMaskPawnQuiet(source, us)):
          return false
        if enPassantTarget notin a1 .. h8:
          return false
        if empty(
          enPassantTarget.toBitboard and attackMaskPawnQuiet(target, enemy) and
            attackMaskPawnQuiet(source, us)
        ):
          return false
      elif enPassantTarget != noSquare:
        return false

  if promoted != noPiece:
    if moved != pawn:
      return false
    if promoted notin knight .. queen:
      return false
    if empty(target.toBitboard and (ranks[a1] or ranks[a8])):
      return false

  if move.castled:
    let castlingSide = position.castlingSide(move)

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

func calculateZobristKey*(position: Position): ZobristKey =
  result =
    position.enPassantTarget.ZobristKey xor zobristSideToMoveBitmasks[position.us]
  for color in white .. black:
    for piece in pawn .. king:
      for square in position[piece, color]:
        result ^= zobristPieceBitmasks[color][piece][square]

    for side in queenside .. kingside:
      let rookSource = position.rookSource[color][side]
      result ^= cast[ZobristKey](rookSource)

func doMove*(position: Position, move: Move): Position =
  result = position
  assert result.isPseudoLegal(move), $position & ", " & $move
  let
    target = move.target
    source = move.source
    moved = move.moved
    captured = move.captured
    promoted = move.promoted
    enPassantTarget = move.enPassantTarget
    us = result.us
    enemy = result.enemy

  result.zobristKey ^= cast[ZobristKey](result.enPassantTarget)
  if enPassantTarget != noSquare:
    result.enPassantTarget = enPassantTarget.toBitboard
  else:
    result.enPassantTarget = 0.Bitboard
  result.zobristKey ^= cast[ZobristKey](result.enPassantTarget)

  if moved == king:
    result.zobristKey ^= cast[ZobristKey](result.rookSource[us][queenside])
    result.zobristKey ^= cast[ZobristKey](result.rookSource[us][kingside])
    result.rookSource[us] = [noSquare, noSquare]
    # We should xor by noSquare twice, but that's basically a no-op

  for side in queenside .. kingside:
    if result.rookSource[us][side] == source:
      result.zobristKey ^= cast[ZobristKey](result.rookSource[us][side])
      result.rookSource[us][side] = noSquare
      result.zobristKey ^= cast[ZobristKey](noSquare)
    if result.rookSource[enemy][side] == target:
      result.zobristKey ^= cast[ZobristKey](result.rookSource[enemy][side])
      result.rookSource[enemy][side] = noSquare
      result.zobristKey ^= cast[ZobristKey](noSquare)

  # en passant
  if move.capturedEnPassant:
    result.removePiece(enemy, pawn, attackMaskPawnQuiet(target, enemy).toSquare)
    result.movePiece(us, pawn, source, target)

    let capturedSquare = attackMaskPawnQuiet(target, enemy).toSquare
    result.zobristKey ^= zobristPieceBitmasks[enemy][pawn][capturedSquare]

  # removing captured piece
  elif captured != noPiece:
    result.removePiece(enemy, captured, target)
    result.zobristKey ^= zobristPieceBitmasks[enemy][captured][target]

  # castling
  if move.castled:
    let
      rookSource = target
      kingSource = source
      castlingSide = position.castlingSide(move)
      rookTarget = rookTarget[us][castlingSide]
      kingTarget = kingTarget[us][castlingSide]

    result.removePiece(us, king, kingSource)
    result.removePiece(us, rook, rookSource)

    for (piece, source, target) in [
      (king, kingSource, kingTarget), (rook, rookSource, rookTarget)
    ]:
      result.addPiece(us, piece, target)
      result.zobristKey ^= zobristPieceBitmasks[us][piece][source]
      result.zobristKey ^= zobristPieceBitmasks[us][piece][target]

  # moving piece
  else:
    result.zobristKey ^= zobristPieceBitmasks[us][moved][source]
    if promoted != noPiece:
      result.removePiece(us, moved, source)
      result.addPiece(us, promoted, target)
      result.zobristKey ^= zobristPieceBitmasks[us][promoted][target]
    else:
      result.movePiece(us, moved, source, target)
      result.zobristKey ^= zobristPieceBitmasks[us][moved][target]

  result.halfmovesPlayed += 1
  result.halfmoveClock += 1
  if moved == pawn or captured != noPiece:
    result.halfmoveClock = 0

  result.us = result.enemy

  result.zobristKey ^= zobristSideToMoveBitmasks[white]
  result.zobristKey ^= zobristSideToMoveBitmasks[black]

  assert result.zobristKey == result.calculateZobristKey

func doNullMove*(position: Position): Position =
  result = position

  result.zobristKey ^= cast[ZobristKey](result.enPassantTarget)
  result.enPassantTarget = 0.Bitboard

  result.zobristKey ^= zobristSideToMoveBitmasks[white]
  result.zobristKey ^= zobristSideToMoveBitmasks[black]

  result.halfmoveClock = 0

  result.us = result.enemy

  assert result.zobristKey == result.calculateZobristKey

func kingSquare*(position: Position, color: Color): Square =
  assert (position[king] and position[color]).countSetBits == 1
  (position[king] and position[color]).toSquare

func inCheck*(position: Position, us: Color): bool =
  position.isAttacked(us, position.kingSquare(us))

func isLegal*(position: Position, move: Move): bool =
  if not position.isPseudoLegal(move):
    return false
  let newPosition = position.doMove(move)
  return not newPosition.inCheck(position.us)

func coloredPiece*(position: Position, square: Square): ColoredPiece =
  for color in white .. black:
    for piece in pawn .. king:
      if not empty(square.toBitboard and position[piece] and position[color]):
        return ColoredPiece(piece: piece, color: color)
  ColoredPiece(piece: noPiece, color: noColor)

func addColoredPiece*(
    position: var Position, coloredPiece: ColoredPiece, square: Square
) =
  for color in position.colors.mitems:
    color &= not square.toBitboard
  for piece in position.pieces.mitems:
    piece &= not square.toBitboard

  position.addPiece(coloredPiece.color, coloredPiece.piece, square)

func isPassedPawn*(position: Position, us: Color, square: Square): bool =
  empty(isPassedMask[us][square] and position[pawn] and position[us.opposite])

func isPassedPawnMove*(newPosition: Position, move: Move): bool =
  move.moved == pawn and newPosition.isPassedPawn(newPosition.enemy, move.target)

func gamePhase*(position: Position): GamePhase =
  position.occupancy.countSetBits.clampToType(GamePhase)

func mirror(
    position: Position,
    skipZobristKey: static bool,
    mirrorFn: proc(bitboard: Bitboard): Bitboard {.noSideEffect.},
): Position =
  result = position

  for bitboard in result.pieces.mitems:
    bitboard = bitboard.mirrorFn
  for bitboard in result.colors.mitems:
    bitboard = bitboard.mirrorFn

  result.enPassantTarget = result.enPassantTarget.mirrorFn

  for color in white .. black:
    for castlingSide in queenside .. kingside:
      if result.rookSource[color][castlingSide] != noSquare:
        result.rookSource[color][castlingSide] =
          result.rookSource[color][castlingSide].toBitboard.mirrorFn.toSquare

func mirrorVertically*(
    position: Position,
    skipZobristKey: static bool = false,
    swapColors: static bool = true,
): Position =
  result = position.mirror(skipZobristKey, mirrorVertically)

  when swapColors:
    swap result.rookSource[black], result.rookSource[white]
    result.us = result.enemy
    swap result.colors[white], result.colors[black]

  when not skipZobristKey:
    result.zobristKey = result.calculateZobristKey

func mirrorHorizontally*(
    position: Position, skipZobristKey: static bool = false
): Position =
  result = position.mirror(skipZobristKey, mirrorHorizontally)

  for color in white .. black:
    swap result.rookSource[color][kingside], result.rookSource[color][queenside]

  when not skipZobristKey:
    result.zobristKey = result.calculateZobristKey

func rotate*(
    position: Position,
    skipZobristKey: static bool = false,
    swapColors: static bool = true,
): Position =
  result = position.mirrorHorizontally(skipZobristKey = true).mirrorVertically(
      skipZobristKey = true, swapColors = swapColors
    )

  when not skipZobristKey:
    result.zobristKey = result.calculateZobristKey

func insufficientMaterial*(position: Position): bool =
  empty(position[pawn] or position[rook] or position[queen]) and
    (position[bishop] or position[knight]).countSetBits <= 1

func isChess960*(position: Position): bool =
  for color in white .. black:
    if position.rookSource[color] != [noSquare, noSquare] and
        position.kingSquare(color) != classicalKingSource[color]:
      return true
    for side in queenside .. kingside:
      if position.rookSource[color][side] notin
          [noSquare, classicalRookSource[color][side]]:
        return true
  false
