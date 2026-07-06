import nimchess

import types

#!fmt: off
func value*(piece: Piece): Value =
  const table = [pawn: 0.32239842.Value, knight: 1.0803405.Value, bishop: 1.1097395.Value, rook: 1.6884761.Value, queen: 3.6470497.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
#!fmt: on
