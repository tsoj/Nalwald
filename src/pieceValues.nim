import evalParameters

func value*(piece: Piece): Value =
  const table = [pawn: 112.Value, knight: 431.Value, bishop: 449.Value, rook: 619.Value, queen: 1351.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
