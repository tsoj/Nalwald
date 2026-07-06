import nimchess

import types

func value*(piece: Piece): Value =
  const table = [pawn: 0.30897307.Value, knight: 0.8749822.Value, bishop: 0.9424647.Value, rook: 1.4613937.Value, queen: 2.7174075.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
