import nimchess

import types

#!fmt: off
func value*(piece: Piece): Value =
  const table = [pawn: 0.41407838.Value, knight: 1.4636368.Value, bishop: 1.5286024.Value, rook: 2.2442784.Value, queen: 5.581564.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
#!fmt: on
