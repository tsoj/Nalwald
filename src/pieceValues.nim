import evalParameters

func value*(piece: Piece): Value =
  const table = [pawn: 144.Value, knight: 469.Value, bishop: 508.Value, rook: 734.Value, queen: 1478.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
