import nimchess

import types

func value*(piece: Piece): Value =
  const table = [pawn: 0.27285966.Value, knight: 0.81894535.Value, bishop: 0.8689812.Value, rook: 1.3323474.Value, queen: 2.7962947.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
