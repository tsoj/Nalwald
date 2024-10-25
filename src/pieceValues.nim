import evalParameters

func value*(piece: Piece): Value =
  const table = [pawn: 141.Value, knight: 453.Value, bishop: 492.Value, rook: 714.Value, queen: 1397.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
