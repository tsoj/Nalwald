import
    position,
    bitboard,
    move,
    types,
    castling
import
    strutils,
    utils

func generateCaptures(position: Position, piece: Piece, moves: var openArray[Move]): int =
    result = 0
    var pieceOccupancy = position[position.us] and position[piece]
    while pieceOccupancy != 0:
        let source = pieceOccupancy.removeTrailingOneBit.Square
        var attackMask = piece.attackMask(source, position.occupancy) and position[position.enemy]
        while attackMask != 0:
            let target = attackMask.removeTrailingOneBit.Square
            for captured in pawn..king:
                if (position[captured] and bitAt[target]) != 0:
                    moves[result].create(
                        source = source, target = target, enPassantTarget = noSquare,
                        moved = piece, captured = captured, promoted = noPiece,
                        castled = false, capturedEnPassant = false
                    )
                    result += 1
                    break

func generateQuiets(position: Position, piece: Piece, moves: var openArray[Move]): int =
    let occupancy = position.occupancy
    result = 0
    var pieceOccupancy = position[position.us] and position[piece]
    while pieceOccupancy != 0:
        let source = pieceOccupancy.removeTrailingOneBit.Square
        var attackMask = piece.attackMask(source, occupancy) and (not occupancy)
        while attackMask != 0:
            let target = attackMask.removeTrailingOneBit.Square
            moves[result].create(
                source = source, target = target, enPassantTarget = noSquare,
                moved = piece, captured = noPiece, promoted = noPiece,
                castled = false, capturedEnPassant = false
            )
            result += 1

func generatePawnCaptures(position: Position, moves: var openArray[Move]): int =
    let
        us = position.us
        enemy = position.enemy
    result = 0

    proc addPromotions(moves: var openArray[Move], source, target: Square, counter: var int, captured = noPiece) =
        for promoted in knight..queen:
            moves[counter].create(
                source = source, target = target, enPassantTarget = noSquare,
                moved = pawn, captured = captured, promoted = promoted,
                castled = false, capturedEnPassant = false
            )
            counter += 1

    var pawnOccupancy = position[pawn] and position[us]
    while pawnOccupancy != 0:
        let source = pawnOccupancy.removeTrailingOneBit.Square
        # quiet promotions
        if (bitAt[source] and pawnHomeRank[enemy]) != 0 and (pawnQuietAttackTable[us][source] and position.occupancy) == 0:
            let target = pawnQuietAttackTable[us][source].toSquare
            moves.addPromotions(source, target, result)

        # captures
        var attackMask = pawnCaptureAttackTable[us][source] and position[enemy]
        while attackMask != 0:
            let target = attackMask.removeTrailingOneBit.Square
            for captured in pawn..king:
                if (position[captured] and bitAt[target]) != 0:
                    if (bitAt[target] and homeRank[enemy]) != 0:
                        moves.addPromotions(source, target, result, captured)
                    else:
                        moves[result].create(
                            source = source, target = target, enPassantTarget = noSquare,
                            moved = pawn, captured = captured, promoted = noPiece,
                            castled = false, capturedEnPassant = false
                        )
                        result += 1
                    break

        # en passant capture
        attackMask = pawnCaptureAttackTable[us][source] and position.enPassantCastling and (ranks[a3] or ranks[a6])
        if attackMask != 0:
            let target = attackMask.toSquare
            moves[result].create(
                source = source, target = target, enPassantTarget = noSquare,
                moved = pawn, captured = pawn, promoted = noPiece,
                castled = false, capturedEnPassant = true
            )
            result += 1

func generatePawnQuiets(position: Position, moves: var openArray[Move]): int =
    let
        us = position.us
        occupancy = position.occupancy
    result = 0
    var pawnOccupancy = position[pawn] and position[us]
    while pawnOccupancy != 0:
        let source = pawnOccupancy.removeTrailingOneBit.Square
        if (pawnQuietAttackTable[us][source] and (occupancy or homeRank[position.enemy])) == 0:
            let target = pawnQuietAttackTable[us][source].toSquare
            moves[result].create(
                source = source, target = target, enPassantTarget = noSquare,
                moved = pawn, captured = noPiece, promoted = noPiece,
                castled = false, capturedEnPassant = false
            )
            result += 1

            # double pushs
            if (bitAt[source] and pawnHomeRank[us]) != 0:
                let doublePushTarget = pawnQuietAttackTable[us][target].toSquare
                if (bitAt[doublePushTarget] and occupancy) == 0:
                    moves[result].create(
                        source = source, target = doublePushTarget, enPassantTarget = target,
                        moved = pawn, captured = noPiece, promoted = noPiece,
                        castled = false, capturedEnPassant = false
                    )
                    result += 1

func generateCastlingMoves(position: Position, moves: var openArray[Move]): int =
    let
        us = position.us
        enemy = position.enemy
        occupancy = position.occupancy
        kingSource = (position[us] and position[king]).toSquare

    result = 0
    for (castlingSide, rookSource) in position.rookSource[us].pairs:
        # castling is still allowed
        if (position.enPassantCastling and bitAt[rookSource] and homeRank[us]) == 0:
            continue

        # all necessary squares are empty
        if (blockSensitive(castlingSide, us, kingSource, rookSource) and occupancy) != 0:
            continue

        # king will never be in check
        var kingInCheck = false
        for checkSquare in checkSensitive[castlingSide][us][kingSource]:
            if position.isAttacked(us, enemy, checkSquare):
                kingInCheck = true
                break
        if kingInCheck:
            continue

        moves[result].create(
            source = kingSource, target = rookSource, enPassantTarget = noSquare,
            moved = king, captured = noPiece, promoted = noPiece,
            castled = true, capturedEnPassant = false
        )
        result += 1

func generateCaptures*(position: Position, moves: var openArray[Move]): int =
    result = position.generatePawnCaptures(moves)
    for piece in knight..king:
        result += position.generateCaptures(piece, moves.toOpenArray(result, moves.len - 1))

func generateQuiets*(position: Position, moves: var openArray[Move]): int =
    result = position.generatePawnQuiets(moves)
    result += position.generateCastlingMoves(moves.toOpenArray(result, moves.len - 1))
    for piece in knight..king:
        result += position.generateQuiets(piece, moves.toOpenArray(result, moves.len - 1))

func generateMoves*(position: Position, moves: var openArray[Move]): int =
    result = position.generateCaptures(moves)
    result += position.generateQuiets(moves.toOpenArray(result, moves.len - 1))

func legalMoves*(position: Position): seq[Move] =
    var moveArray: array[256, Move]
    let numMoves = position.generateMoves(moveArray)
    for i in 0..<numMoves:
        var newPosition = position
        newPosition.doMove(moveArray[i])
        if newPosition.inCheck(position.us, position.enemy):
            continue
        result.add(moveArray[i])

func toMove*(s: string, position: Position): Move =
    # TODO: move to better place (not movegen)

    doAssert s.len == 4 or s.len == 5

    let
        source = parseEnum[Square](s[0..1])
        target = parseEnum[Square](s[2..3])
        promoted = if s.len == 5: s[4].toColoredPiece.piece else: noPiece

    for move in position.legalMoves:
        if move.source == source and move.promoted == promoted:
            if move.target == target:
                return move
            if move.castled and target == kingTarget[position.castlingSide(move)][position.us] and not position.isChess960:
                return move
    doAssert false, "Move is illegal: " & s
