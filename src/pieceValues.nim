import evalParameters

func value*(piece: Piece): Value =
  const table = [pawn: 141.Value, knight: 452.Value, bishop: 491.Value, rook: 713.Value, queen: 1394.Value, king: valueCheckmate, noPiece: 0.Value]
  table[piece]
