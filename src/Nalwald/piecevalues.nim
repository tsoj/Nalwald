import nimchess

import types

func value*(piece: Piece): Value =
  const table = [
    pawn: 0.2907708.Value,
    knight: 0.68735003.Value,
    bishop: 0.73456645.Value,
    rook: 1.1526169.Value,
    queen: 2.1108224.Value,
    king: valueCheckmate,
    noPiece: 0.Value,
  ]
  table[piece]
