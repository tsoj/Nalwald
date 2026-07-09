import nimchess

import types

#!fmt: off
func value*(piece: Piece): Value =
  const table = [pawn: 0.40252742.Value, knight: 1.2913749.Value, bishop: 1.3843408.Value, rook: 2.0380604.Value, queen: 4.4362316.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
#!fmt: on
