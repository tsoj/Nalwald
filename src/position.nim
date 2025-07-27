import types, bitboard, castling, zobristBitmasks
export type, bitboard, castling


type Position* = object
  pieces*: array[pawn .. king, Bitboard]
  colors*: array[white .. black, Bitboard]
  enPassantTarget*: Square
  rookSource*: array[white .. black, array[CastlingSide, Square]]
  us*: Color
  halfmovesPlayed*: int
  halfmoveClock*: int
  pawnKey*: Key
  zobristKey*: Key


func enemy*(position: Position): Color =
  position.us.opposite

func `[]`*(position: Position, piece: Piece): Bitboard =
  position.pieces[piece]

func `[]`*(position: var Position, piece: Piece): var Bitboard =
  position.pieces[piece]

func `[]=`*(position: var Position, piece: Piece, bitboard: Bitboard) =
  position.pieces[piece] = bitboard

func `[]`*(position: Position, color: Color): Bitboard =
  position.colors[color]

func `[]`*(position: var Position, color: Color): var Bitboard =
  position.colors[color]

func `[]=`*(position: var Position, color: Color, bitboard: Bitboard) =
  position.colors[color] = bitboard

func `[]`*(position: Position, piece: Piece, color: Color): Bitboard =
  position[color] and position[piece]
func `[]`*(position: Position, color: Color, piece: Piece): Bitboard =
  position[color] and position[piece]


func addPiece*(
    position: var Position, color: Color, piece: Piece, target: Square
) =
  let bit = target.toBitboard
  position[piece] |= bit
  position[color] |= bit

  position.zobristKey ^= zobristPieceBitmasks[color][piece][target]
  if piece == pawn:
    position.pawnKey ^= zobristPieceBitmasks[color][piece][target]

func removePiece*(
    position: var Position, color: Color, piece: Piece, source: Square
) =
  let bit = not source.toBitboard
  position[piece] &= bit
  position[color] &= bit

  position.zobristKey ^= zobristPieceBitmasks[color][piece][source]
  if piece == pawn:
    position.pawnKey ^= zobristPieceBitmasks[color][piece][source]

func movePiece*(
    position: var Position, color: Color, piece: Piece, source, target: Square
) =
  position.removePiece(color, piece, source)
  position.addPiece(color, piece, target)

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

func kingSquare*(position: Position, color: Color): Square =
  assert (position[king] and position[color]).countSetBits == 1
  (position[king] and position[color]).toSquare

func inCheck*(position: Position, us: Color): bool =
  position.isAttacked(us, position.kingSquare(us))

func pieceAt*(position: Position, square: Square): Piece =
  let bit = square.toBitboard
  for piece, bitboard in position.pieces.pairs:
    if not empty(bitboard and bit):
      return piece
  noPiece

func coloredPieceAt*(position: Position, square: Square): ColoredPiece =
  let piece = position.pieceAt(square)
  if piece == noPiece:
    ColoredPiece(piece: noPiece)
  else:
    let piece: pawn..king = piece
    ColoredPiece(piece: piece, color: if position[white].isSet(square): white else: black)

func addColoredPiece*(
    position: var Position, coloredPiece: ColoredPiece, square: Square
) =
  for color in position.colors.mitems:
    color &= not square.toBitboard
  for piece in position.pieces.mitems:
    piece &= not square.toBitboard

  position.addPiece(coloredPiece.color, coloredPiece.piece, square)

func calculateZobristKeys*(
    position: Position
): tuple[zobristKey: Key, pawnKey: Key] =
  result = (
    zobristKey:
      position.enPassantTarget.Key xor zobristSideToMoveBitmasks[position.us],
    pawnKey: 0.Key,
  )
  for color in white .. black:
    for piece in pawn .. king:
      for square in position[piece, color]:
        result.zobristKey ^= zobristPieceBitmasks[color][piece][square]
        if piece == pawn:
          result.pawnKey ^= zobristPieceBitmasks[color][piece][square]

    for side in queenside .. kingside:
      let rookSource = position.rookSource[color][side]
      result.zobristKey ^= rookSourceBitmasks[rookSource]

func zobristKeysAreOk*(position: Position): bool =
  (position.zobristKey, position.pawnKey) == position.calculateZobristKeys

func setZobristKeys*(position: var Position) =
  (position.zobristKey, position.pawnKey) = position.calculateZobristKeys


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


func mirror(
    position: Position,
    mirrorFn: proc(bitboard: Bitboard): Bitboard {.noSideEffect.},
): Position =
  result = position

  for bitboard in result.pieces.mitems:
    bitboard = bitboard.mirrorFn
  for bitboard in result.colors.mitems:
    bitboard = bitboard.mirrorFn

  result.enPassantTarget = result.enPassantTarget.toBitboard.mirrorFn.toSquare

  for color in white .. black:
    for castlingSide in queenside .. kingside:
      if result.rookSource[color][castlingSide] != noSquare:
        result.rookSource[color][castlingSide] =
          result.rookSource[color][castlingSide].toBitboard.mirrorFn.toSquare

func mirrorVertically*(
    position: Position,
    swapColors: static bool = true,
    skipKeyCalculation: static bool = false,
): Position =
  result = position.mirror(mirrorVertically)

  when swapColors:
    swap result.rookSource[white], result.rookSource[black]
    swap result.colors[white], result.colors[black]
    result.halfmovesPlayed += (if result.us == black: -1 else: +1)
    result.us = result.enemy

  when not skipKeyCalculation:
    result.setZobristKeys

func mirrorHorizontally*(
    position: Position, skipKeyCalculation: static bool = false
): Position =
  result = position.mirror(mirrorHorizontally)

  for color in white .. black:
    swap result.rookSource[color][kingside], result.rookSource[color][queenside]

  when not skipKeyCalculation:
    result.setZobristKeys
