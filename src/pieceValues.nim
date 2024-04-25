import evalParameters

func value*(piece: Piece): Value =
  const table = [pawn: 143.Value, knight: 464.Value, bishop: 499.Value, rook: 726.Value, queen: 1413.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
