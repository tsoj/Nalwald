import nimchess

import types

func value*(piece: Piece): Value =
  const table = [
    pawn: 0.27807832.Value,
    knight: 0.86215657.Value,
    bishop: 0.88966936.Value,
    rook: 1.3782328.Value,
    queen: 2.9001288.Value,
    king: valueCheckmate,
    noPiece: 0.Value,
  ]
  table[piece]
