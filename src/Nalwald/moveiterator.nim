import nimchess

import searchpos

iterator treeSearchMoveIterator*(
    position: SearchPos, hashMove: Move = noMove, doQuiets: static bool = true
): (SearchPos, Move) =
  ## This iterator is optimized for speed and for good move ordering.
  ## It does not guarantee to list all legal moves and may include
  ## illegal moves that leave our own king in check.

  if position.isPseudoLegal(hashMove):
    yield (position.doMove(hashMove), hashMove)

  var pseudoLegalMoves: array[320, Move]
  let numMoves = position.generateMoves(pseudoLegalMoves)
  doAssert pseudoLegalMoves.len > numMoves

  for move in pseudoLegalMoves[0 ..< numMoves]:
    if move == hashMove:
      continue

    let newPosition = position.doMove move

    if newPosition.inCheck(position.pos.us):
      continue

    if not doQuiets and not move.isTactical:
      continue

    yield (newPosition, move)
