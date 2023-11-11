import
    position,
    bitboard,
    move,
    types,
    castling

template addMove(
    moves: var openArray[Move], index: var int, 
    source, target, enPassantTarget: Square,
    moved, captured, promoted: Piece,
    castled, capturedEnPassant: bool
) =
    if moves.len > index:
        moves[index].create(
            source, target, enPassantTarget,
            moved, captured, promoted,
            castled, capturedEnPassant
        )
        index += 1

func generateCaptures(position: Position, piece: Piece, moves: var openArray[Move]): int =
    result = 0
    for source in position[position.us] and position[piece]:
        for target in piece.attackMask(source, position.occupancy) and position[position.enemy]:
            for captured in pawn..king:
                if (position[captured] and target.toBitboard) != 0:
                    moves.addMove(
                        result,
                        source = source, target = target, enPassantTarget = noSquare,
                        moved = piece, captured = captured, promoted = noPiece,
                        castled = false, capturedEnPassant = false
                    )
                    break

func generateQuiets(position: Position, piece: Piece, moves: var openArray[Move]): int =
    let occupancy = position.occupancy
    result = 0
    for source in position[position.us] and position[piece]:
        for target in piece.attackMask(source, occupancy) and not occupancy:
            moves.addMove(
                result,
                source = source, target = target, enPassantTarget = noSquare,
                moved = piece, captured = noPiece, promoted = noPiece,
                castled = false, capturedEnPassant = false
            )

const firstPawnPushRank = [
    white: homeRank[white].up(white).up(white),
    black: homeRank[black].up(black).up(black)
]

func generatePawnCaptures(position: Position, moves: var openArray[Move]): int =
    let
        us = position.us
        enemy = position.enemy
    result = 0

    proc addPromotions(moves: var openArray[Move], source, target: Square, counter: var int, captured = noPiece) =
        for promoted in knight..queen:
            moves.addMove(
                counter,
                source = source, target = target, enPassantTarget = noSquare,
                moved = pawn, captured = captured, promoted = promoted,
                castled = false, capturedEnPassant = false
            )

    for source in position[pawn] and position[us]:
        # quiet promotions
        if (source.toBitboard and pawnHomeRank[enemy]) != 0 and (attackMaskPawnQuiet(source, us) and position.occupancy) == 0:
            let target = attackMaskPawnQuiet(source, us).toSquare
            moves.addPromotions(source, target, result)

        # captures
        for target in attackMaskPawnCapture(source, us) and position[enemy]:
            for captured in pawn..king:
                if (position[captured] and target.toBitboard) != 0:
                    if (target.toBitboard and homeRank[enemy]) != 0:
                        moves.addPromotions(source, target, result, captured)
                    else:
                        moves.addMove(
                            result,
                            source = source, target = target, enPassantTarget = noSquare,
                            moved = pawn, captured = captured, promoted = noPiece,
                            castled = false, capturedEnPassant = false
                        )
                    break

        # en passant capture
        let attackMask = attackMaskPawnCapture(source, us) and position.enPassantCastling and (ranks[a3] or ranks[a6])
        if attackMask != 0:
            let target = attackMask.toSquare
            moves.addMove(
                result,
                source = source, target = target, enPassantTarget = noSquare,
                moved = pawn, captured = pawn, promoted = noPiece,
                castled = false, capturedEnPassant = true
            )

func generatePawnQuiets(position: Position, moves: var openArray[Move]): int =
    let
        us = position.us
        enemy = position.enemy
        occupancy = position.occupancy

    # debugEcho "-------------------"
    # debugEcho position
    result = 0
    let targets = position[pawn, us].up(us) and not (occupancy or homeRank[enemy])
    # debugEcho targets.bitboardString
    for target in targets:
        let source = target.up(enemy)
        moves.addMove(
            result,
            source = source, target = target, enPassantTarget = noSquare,
            moved = pawn, captured = noPiece, promoted = noPiece,
            castled = false, capturedEnPassant = false
        )

    let doubleTargets = (targets and firstPawnPushRank[us]).up(us) and not occupancy
    # debugEcho doubleTargets.bitboardString
    for target in doubleTargets:
        let
            enPassantTarget = target.up(enemy)
            source = enPassantTarget.up(enemy)
        moves.addMove(
            result,
            source = source, target = target, enPassantTarget = enPassantTarget,
            moved = pawn, captured = noPiece, promoted = noPiece,
            castled = false, capturedEnPassant = false
        )

func generateCastlingMoves(position: Position, moves: var openArray[Move]): int =
    let
        us = position.us
        occupancy = position.occupancy
        kingSource = (position[us] and position[king]).toSquare

    result = 0
    for (castlingSide, rookSource) in position.rookSource[us].pairs:
        # castling is still allowed
        if (position.enPassantCastling and rookSource.toBitboard and homeRank[us]) == 0:
            continue

        # all necessary squares are empty
        if (blockSensitive(us, castlingSide, kingSource, rookSource) and occupancy) != 0:
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
            source = kingSource, target = rookSource, enPassantTarget = noSquare,
            moved = king, captured = noPiece, promoted = noPiece,
            castled = true, capturedEnPassant = false
        )

func generateCaptures*(position: Position, moves: var openArray[Move]): int =
    ## Generates pseudo-legal capture moves and writes the into the `moves` array, starting from index 0.
    ## This function will silently stop generating moves if the `moves` array fills up.
    result = position.generatePawnCaptures(moves)
    for piece in knight..king:
        result += position.generateCaptures(piece, moves.toOpenArray(result, moves.len - 1))

func generateQuiets*(position: Position, moves: var openArray[Move]): int =
    ## Generates pseudo-legal quiet moves and writes the into the `moves` array, starting from index 0.
    ## This function will silently stop generating moves if the `moves` array fills up.
    result = position.generatePawnQuiets(moves)
    result += position.generateCastlingMoves(moves.toOpenArray(result, moves.len - 1))
    for piece in knight..king:
        result += position.generateQuiets(piece, moves.toOpenArray(result, moves.len - 1))

func generateMoves*(position: Position, moves: var openArray[Move]): int =
    ## Generates pseudo-legal moves and writes the into the `moves` array, starting from index 0.
    ## This function will silently stop generating moves if the `moves` array fills up.
    result = position.generateCaptures(moves)
    result += position.generateQuiets(moves.toOpenArray(result, moves.len - 1))
