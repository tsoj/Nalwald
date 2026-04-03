import nimchess

import types

func value*(piece: Piece): Value =
  case piece
  of pawn: 1.Value
  of knight: 3.Value
  of bishop: 3.Value
  of rook: 5.Value
  of queen: 9.Value
  of king: 0.Value
  of noPiece: 0.Value

func eval*(pos: Position): Value =
  result = 0
  for piece in pawn .. king:
    result += (pos[piece, pos.us]).countSetBits.Value * piece.value
    result -= (pos[piece, pos.enemy]).countSetBits.Value * piece.value
