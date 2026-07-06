import nimchess

import types

func value*(piece: Piece): Value =
  const table = [pawn: 0.2913666.Value, knight: 0.8748637.Value, bishop: 0.90410614.Value, rook: 1.4198257.Value, queen: 2.8842623.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
