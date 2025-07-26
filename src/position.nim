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

func removePiece*(
    position: var Position, color: Color, piece: Piece, source: Square
) =
  let bit = not source.toBitboard
  position[piece] &= bit
  position[color] &= bit

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

func checkCheck*(position: Position, us: Color): bool =
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

func calculateZobristKey*(position: Position): Key =
  result =
    position.enPassantTarget.Key xor zobristSideToMoveBitmasks[position.us]
  for color in white .. black:
    for piece in pawn .. king:
      for square in position[piece, color]:
        result ^= zobristPieceBitmasks[color][piece][square]

    for side in queenside .. kingside:
      let rookSource = position.rookSource[color][side]
      result ^= rookSource.Key


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
