import nimchess

import searchpos, piecevalues, searchutils

iterator treeSearchMoveIterator*(
    pos: SearchPos,
    hashMove: Move = noMove,
    historyTable: HistoryTable or tuple[] = (),
    doQuiets: static bool = true,
): (SearchPos, Move) =
  ## This iterator is optimized for speed and for good move ordering.
  ## It does not guarantee to list all legal moves and may include
  ## illegal moves that leave our own king in check.

  type OrderedMoveList[maxMoves: static int] = object
    moves: array[maxMoves, Move]
    scores: array[maxMoves, float32]
    numMoves: int

  if pos.isPseudoLegal(hashMove):
    yield (pos.doMove(hashMove), hashMove)

  var moveList: OrderedMoveList[192]

  template yieldOrderedMoves(generate, scoreMove: untyped): untyped =
    moveList.numMoves = pos.generate(moveList.moves)
    doAssert moveList.moves.len > moveList.numMoves

    for i in 0 ..< moveList.numMoves:
      moveList.scores[i] = scoreMove(moveList.moves[i])

    for _ in 0 ..< moveList.numMoves:
      var bestIndex = 0
      for i in 1 ..< moveList.numMoves:
        if moveList.scores[i] > moveList.scores[bestIndex]:
          bestIndex = i

      let move = moveList.moves[bestIndex]
      moveList.scores[bestIndex] = -Inf

      if move == hashMove:
        continue

      let newPos = pos.doMove move

      if newPos.inCheck(pos.pos.us):
        continue

      yield (newPos, move)

  template captureScore(move: Move): float32 =
    move.captured(pos).value + move.promoted.value - move.moved(pos).value / 10.0 +
      queen.value * (
        when historyTable is HistoryTable:
          historyTable.get(pos, move)
        else:
          0.0
      )

  yieldOrderedMoves(generateCaptures, captureScore)

  if doQuiets:
    template quietScore(move: Move): float32 =
      when historyTable is HistoryTable:
        historyTable.get(pos, move)
      else:
        0.0

    yieldOrderedMoves(generateQuiets, quietScore)
