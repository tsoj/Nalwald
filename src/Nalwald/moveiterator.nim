import nimchess

import searchpos, piecevalues

iterator treeSearchMoveIterator*(
    pos: SearchPos, hashMove: Move = noMove, doQuiets: static bool = true
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

  var moveList: OrderedMoveList[320]
  moveList.numMoves = pos.generateMoves(moveList.moves)
  doAssert moveList.moves.len > moveList.numMoves

  for i in 0 ..< moveList.numMoves:
    let move = moveList.moves[i]
    moveList.scores[i] =
      move.captured(pos).value + move.promoted.value - move.moved(pos).value / 10.0

  for _ in 0 ..< moveList.numMoves:
    var bestIndex = 0
    for i in 1 ..< moveList.numMoves:
      if moveList.scores[i] > moveList.scores[bestIndex]:
        bestIndex = i

    let move = moveList.moves[bestIndex]
    moveList.scores[bestIndex] = -Inf

    if move == hashMove:
      continue

    if not doQuiets and not move.isTactical:
      continue

    let newPos = pos.doMove move

    if newPos.inCheck(pos.pos.us):
      continue

    yield (newPos, move)
