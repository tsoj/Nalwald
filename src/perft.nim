import position, chessStrutils, move, movegen, utils

func perft*(position: Position, depth: int, printRootMoveNodes: static bool = false): int64 =
  if depth <= 0:
    return 1
  var moves: array[320, Move]
  let numMoves = position.generateMoves(moves)
  assert numMoves < 320
  for i in 0 ..< numMoves:
    template move(): Move =
      moves[i]

    let newPosition = position.doMove(move)
    if not newPosition.checkCheck(position.us):
      let nodes = newPosition.perft(depth - 1)
      when printRootMoveNodes and not defined smallBuild:
        debugEcho "    ", move, " ", nodes, " ", newPosition.fen
      result += nodes


# const perftFens* = [
#   # classical positions
#   ("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w QKqk - 0 1", @[48, 2039, 97862, 4085603, 193690690]),
#   ("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", @[14, 191, 2812, 43238, 674624, 11030083, 178633661]),
#   ("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w qk - 0 1", @[6, 264, 9467, 422333, 15833292]),
#   ("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w QK - 1 8", @[44, 1486, 62379, 2103487, 89941194]),
#   ("r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10", @[46, 2079, 89890, 3894594, 164075551]),
#   ("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w QKqk -", @[20, 400, 8902, 197281, 4865609, 119060324]),
#   ("4k3/8/8/8/8/8/8/4K2R w K - 0 1", @[15, 66, 1197, 7059, 133987, 764643]),
#   ("QQQQQQBk/Q6B/Q6Q/Q6Q/Q6Q/Q6Q/Q6Q/KQQQQQQQ w - - 0 1", @[265]),
# ]

# # let pos = Position(pieces: [12754369552377600u64.Bitboard, 37452115083264u64.Bitboard, 18015498021115904u64.Bitboard, 9295429630892703873u64.Bitboard, 4503599629467648u64.Bitboard, 1152921504606846992u64.Bitboard], colors: [103350075281u64.Bitboard, 10483661951467520000u64.Bitboard], enPassantTarget: 0u64.Bitboard, rookSource: [[a1, h1], [a8, h8]], us: white, halfmovesPlayed: 2, halfmoveClock: 0, materialKey: 0, pawnKey: 0, majorPieceKey: 0, minorPieceKey: 0, nonPawnKey: 0, zobristKey: 15795391754331227165u64.Key)
# let pos = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w QKqk - 0 1".toPosition

# # echo "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPPKNnPP/RNBQ3R b - - 2 8".toPosition.perft(1.Ply, true)


# const maxNumPerftNodes = 100000000
# let start = secondsSince1970()
# var summedNodes = 0
# for (fen, trueNumNodesList) in perftFens:
#   let position = fen.toPosition

#   for depth in 1 .. trueNumNodesList.len:
#     let trueNumNodes = trueNumNodesList[depth - 1]

#     if trueNumNodes > maxNumPerftNodes:
#       break

#     let fastPerftResult = position.perft(depth, false)
#     assert fastPerftResult == trueNumNodes, fen & ", " & $depth
#     summedNodes += trueNumNodes
# echo summedNodes
# echo summedNodes.float / (secondsSince1970()-start).float
