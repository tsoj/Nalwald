import nimchess

import types

#!fmt: off
func value*(piece: Piece): Value =
  const table = [pawn: 0.42911616.Value, knight: 1.3259189.Value, bishop: 1.4288918.Value, rook: 2.1380703.Value, queen: 9.682416.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
#!fmt: on
