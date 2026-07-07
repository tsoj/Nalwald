import nimchess

import types

#!fmt: off
func value*(piece: Piece): Value =
  const table = [pawn: 0.3221577.Value, knight: 1.0777335.Value, bishop: 1.1085387.Value, rook: 1.6835519.Value, queen: 3.6307063.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
#!fmt: on
