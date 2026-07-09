import nimchess

import types

#!fmt: off
func value*(piece: Piece): Value =
  const table = [pawn: 0.40566006.Value, knight: 1.4273093.Value, bishop: 1.4881091.Value, rook: 2.1888201.Value, queen: 5.363045.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
#!fmt: on
