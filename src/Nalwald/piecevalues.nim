import nimchess

import types

func value*(piece: Piece): Value =
  const table = [pawn: 0.3121768.Value, knight: 0.95103383.Value, bishop: 1.0107707.Value, rook: 1.553279.Value, queen: 3.2977438.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
