import nimchess

import types

func value*(piece: Piece): Value =
  const table = [pawn: 0.31278843.Value, knight: 0.9644075.Value, bishop: 1.023284.Value, rook: 1.5886717.Value, queen: 3.381309.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
