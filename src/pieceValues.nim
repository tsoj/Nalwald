import evalParameters

func value*(piece: Piece): Value =
  const table = [pawn: 104.Value, knight: 402.Value, bishop: 421.Value, rook: 586.Value, queen: 1229.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
