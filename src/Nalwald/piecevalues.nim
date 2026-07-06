import nimchess

import types

func value*(piece: Piece): Value =
  const table = [pawn: 0.271808.Value, knight: 0.82385767.Value, bishop: 0.8506573.Value, rook: 1.2928077.Value, queen: 2.8301294.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
