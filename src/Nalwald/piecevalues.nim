import nimchess

import types

func value*(piece: Piece): Value =
  const table = [
    pawn: 0.31304058.Value,
    knight: 0.95035917.Value,
    bishop: 1.0092459.Value,
    rook: 1.5511856.Value,
    queen: 3.290629.Value,
    king: valueCheckmate,
    noPiece: 0.Value,
  ]
  table[piece]
