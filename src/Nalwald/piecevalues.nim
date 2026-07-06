import nimchess

import types

func value*(piece: Piece): Value =
  const table = [pawn: 0.33712408.Value, knight: 1.1426086.Value, bishop: 1.2008091.Value, rook: 1.8742312.Value, queen: 6.900756.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
