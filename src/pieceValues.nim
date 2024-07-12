import evalParameters

func value*(piece: Piece): Value =
  const table = [pawn: 110.Value, knight: 429.Value, bishop: 448.Value, rook: 613.Value, queen: 1339.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
