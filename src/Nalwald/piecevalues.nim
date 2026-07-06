import nimchess

import types

func value*(piece: Piece): Value =
  const table = [pawn: 0.4951925.Value, knight: 0.5987003.Value, bishop: 0.6375936.Value, rook: 0.75183094.Value, queen: 0.8627933.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
