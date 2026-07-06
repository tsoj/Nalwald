import nimchess

import types

func value*(piece: Piece): Value =
  const table = [pawn: 0.24152832.Value, knight: 0.6872378.Value, bishop: 0.6947635.Value, rook: 1.1474837.Value, queen: 2.1260507.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
