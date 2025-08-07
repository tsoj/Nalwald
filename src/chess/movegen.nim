import position, bitboard, move, types, castling

# TODO clean up, remove unused arguments
func addMove(
    moves: var openArray[Move],
    index: var int,
    source, target: Square,
    captured, castled, capturedEnPassant: bool,
    promoted: Piece,
) =
  if moves.len > index:
    moves[index] = newMove(
      source = source,
      target = target,
      captured = captured,
      enPassant = capturedEnPassant,
      castled = castled,
      promoted = promoted,
    )
    index += 1

func generateCaptures(
    position: Position, piece: Piece, moves: var openArray[Move]
): int =
  result = 0
  for source in position[position.us] and position[piece]:
    for target in (
      piece.attackMask(source, position.occupancy) and position[position.enemy]
    ):
      moves.addMove(
        result,
        source = source,
        target = target,
        captured = true,
        castled = false,
        capturedEnPassant = false,
        promoted = noPiece,
      )

func generateQuiets(position: Position, piece: Piece, moves: var openArray[Move]): int =
  let occupancy = position.occupancy
  result = 0
  for source in position[position.us] and position[piece]:
    for target in piece.attackMask(source, occupancy) and not occupancy:
      moves.addMove(
        result,
        source = source,
        target = target,
        captured = false,
        castled = false,
        capturedEnPassant = false,
        promoted = noPiece,
      )

func left(b: Bitboard): Bitboard =
  b shr 1
func right(b: Bitboard): Bitboard =
  b shl 1
func up(b: Bitboard, c: Color): Bitboard =
  if c == white:
    b shl 8
  else:
    b shr 8

func pawnLeftAttack(pawns: Bitboard, color: Color): Bitboard =
  (pawns and not files(a1)).up(color).left
func pawnRightAttack(pawns: Bitboard, color: Color): Bitboard =
  (pawns and not files(h1)).up(color).right

const firstPawnPushRank = [
  white: homeRank(white).up(white).up(white), black: homeRank(black).up(black).up(black)
]

func generatePawnCaptures(position: Position, moves: var openArray[Move]): int =
  proc addPromotions(
      moves: var openArray[Move],
      counter: var int,
      source, target: Square,
      captured: bool,
  ) =
    for promoted in knight .. queen:
      moves.addMove(
        counter,
        source = source,
        target = target,
        captured = captured,
        castled = false,
        capturedEnPassant = false,
        promoted = promoted,
      )

  let
    us = position.us
    enemy = position.enemy
    potentialTargets = position[enemy] or position.enPassantTarget.toBitboard
  for (targets, dir) in [
    (position[pawn, us].pawnLeftAttack(us) and potentialTargets, 1),
    (position[pawn, us].pawnRightAttack(us) and potentialTargets, -1),
  ]:
    for target in targets:
      let
        source = (target.int + dir).Square.up(enemy)
        capturedEnPassant = target == position.enPassantTarget

      if target notin a2 .. h7:
        moves.addPromotions(result, source, target, captured = true)
      else:
        moves.addMove(
          result,
          source = source,
          target = target,
          captured = true,
          castled = false,
          capturedEnPassant = capturedEnPassant,
          promoted = noPiece,
        )

  # quiet promotions
  for target in position[pawn, us].up(us) and homeRank(enemy) and not position.occupancy:
    let source = target.up(enemy)
    moves.addPromotions(result, source, target, captured = false)

func generatePawnQuiets(position: Position, moves: var openArray[Move]): int =
  let
    us = position.us
    enemy = position.enemy
    occupancy = position.occupancy

  let targets = position[pawn, us].up(us) and not (occupancy or homeRank(enemy))
  for target in targets:
    let source = target.up(enemy)
    moves.addMove(
      result,
      source = source,
      target = target,
      captured = false,
      castled = false,
      capturedEnPassant = false,
      promoted = noPiece,
    )

  let doubleTargets = (targets and firstPawnPushRank[us]).up(us) and not occupancy
  for target in doubleTargets:
    let
      enPassantTarget = target.up(enemy)
      source = enPassantTarget.up(enemy)
    moves.addMove(
      result,
      source = source,
      target = target,
      captured = false,
      castled = false,
      capturedEnPassant = false,
      promoted = noPiece,
    )

func generateCastlingMoves(position: Position, moves: var openArray[Move]): int =
  let
    us = position.us
    occupancy = position.occupancy
    kingSource = (position[us] and position[king]).toSquare

  result = 0
  for (castlingSide, rookSource) in position.rookSource[us].pairs:
    # castling is still allowed
    if rookSource == noSquare:
      continue

    # all necessary squares are empty
    if not empty(blockSensitive(us, castlingSide, kingSource, rookSource) and occupancy):
      continue

    # king will never be in check
    var kingInCheck = false
    for checkSquare in checkSensitive[us][castlingSide][kingSource]:
      if position.isAttacked(us, checkSquare):
        kingInCheck = true
        break
    if kingInCheck:
      continue

    moves.addMove(
      result,
      source = kingSource,
      target = rookSource,
      captured = false,
      castled = true,
      capturedEnPassant = false,
      promoted = noPiece,
    )

func generateCaptures*(position: Position, moves: var openArray[Move]): int =
  ## Generates pseudo-legal capture moves and writes the into the `moves` array, starting from index 0.
  ## This function will silently stop generating moves if the `moves` array fills up.
  result = position.generatePawnCaptures(moves)
  for piece in knight .. king:
    result += position.generateCaptures(piece, moves.toOpenArray(result, moves.len - 1))

func generateQuiets*(position: Position, moves: var openArray[Move]): int =
  ## Generates pseudo-legal quiet moves and writes the into the `moves` array, starting from index 0.
  ## This function will silently stop generating moves if the `moves` array fills up.
  result = position.generatePawnQuiets(moves)
  result += position.generateCastlingMoves(moves.toOpenArray(result, moves.len - 1))
  for piece in knight .. king:
    result += position.generateQuiets(piece, moves.toOpenArray(result, moves.len - 1))

func generateMoves*(position: Position, moves: var openArray[Move]): int =
  ## Generates pseudo-legal moves and writes the into the `moves` array, starting from index 0.
  ## This function will silently stop generating moves if the `moves` array fills up.
  result = position.generateCaptures(moves)
  result += position.generateQuiets(moves.toOpenArray(result, moves.len - 1))

func legalMoves*(position: Position): seq[Move] =
  var pseudoLegalMoves = newSeq[Move](64)
  while true:
    # 'generateMoves' silently stops generating moves if the given array is not big enough
    let numMoves = position.generateMoves(pseudoLegalMoves)
    if pseudoLegalMoves.len <= numMoves:
      pseudoLegalMoves.setLen(numMoves * 2)
    else:
      pseudoLegalMoves.setLen(numMoves)
      for move in pseudoLegalMoves:
        let newPosition = position.doMove(move)
        if newPosition.inCheck(position.us):
          continue
        result.add move
      break
