import nimchess

import types

#!fmt: off
func value*(piece: Piece): Value =
  const table = [pawn: 0.42250013.Value, knight: 1.3164449.Value, bishop: 1.4307503.Value, rook: 2.1102395.Value, queen: 4.591611.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
#!fmt: on
