import position
import bitboard
import move
import types
import bitops
import castling

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
                        castled = false, capturedEnPassant = false)
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
                castled = false, capturedEnPassant = false)
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
                castled = false, capturedEnPassant = false)
            counter += 1

    var pawnOccupancy = position[pawn] and position[us]
    while pawnOccupancy != 0:
        let source = pawnOccupancy.removeTrailingOneBit.Square
        # quiet promotions
        if (bitAt[source] and pawnHomeRank[enemy]) != 0 and (pawnQuietAttackTable[us][source] and position.occupancy) == 0:
            let target = pawnQuietAttackTable[us][source].countTrailingZeroBits.Square
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
                            castled = false, capturedEnPassant = false)
                        result += 1
                    break

        # en passant capture
        attackMask = pawnCaptureAttackTable[us][source] and position.enPassantCastling and (ranks[a3] or ranks[a6])
        if attackMask != 0:
            let target = attackMask.countTrailingZeroBits.Square
            moves[result].create(
                source = source, target = target, enPassantTarget = noSquare,
                moved = pawn, captured = pawn, promoted = noPiece,
                castled = false, capturedEnPassant = true)
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
            let target = pawnQuietAttackTable[us][source].countTrailingZeroBits.Square
            moves[result].create(
                source = source, target = target, enPassantTarget = noSquare,
                moved = pawn, captured = noPiece, promoted = noPiece,
                castled = false, capturedEnPassant = false)
            result += 1

            # double pushs
            if (bitAt[source] and pawnHomeRank[us]) != 0:
                let doublePushTarget = pawnQuietAttackTable[us][target].countTrailingZeroBits.Square
                if (bitAt[doublePushTarget] and occupancy) == 0:
                    moves[result].create(
                        source = source, target = doublePushTarget, enPassantTarget = target,
                        moved = pawn, captured = noPiece, promoted = noPiece,
                        castled = false, capturedEnPassant = false)
                    result += 1

func generateCastlingMoves(position: Position, moves: var openArray[Move]): int =
    let
        us = position.us
        enemy = position.enemy
        occupancy = position.occupancy

    if (position.enPassantCastling and bitAt[kingSource[us]]) == 0:
        return 0

    result = 0
    for castlingSide in [queenside, kingside]:
        if (position.enPassantCastling and bitAt[rookSource[castlingSide][us]]) != 0 and
        (blockSensitiveArea[castlingSide][us] and occupancy) == 0 and
        not position.isAttacked(us, enemy, checkSensitive[castlingSide][us][0]) and
        not position.isAttacked(us, enemy, checkSensitive[castlingSide][us][1]):
            moves[result].create(
                source = kingSource[us], target = kingTarget[castlingSide][us], enPassantTarget = noSquare,
                moved = king, captured = noPiece, promoted = noPiece,
                castled = true, capturedEnPassant = false)
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

func generateQuietCheckingMoves*(position: Position, moves: var openArray[Move]): int =
    let
        kingSquare = position.kingSquare(position.enemy)
        occupancy = position.occupancy
        us = position.us
        enemy = position.enemy

    result = 0

    for piece in knight..queen:
        let allowedTargetMask = piece.attackMask(kingSquare, occupancy) and not occupancy
        var pieceOccupancy = position[us] and position[piece]
        while pieceOccupancy != 0:
            let source = pieceOccupancy.removeTrailingOneBit.Square
            var attackMask = piece.attackMask(source, occupancy) and allowedTargetMask
            while attackMask != 0:
                let target = attackMask.removeTrailingOneBit.Square                    
                moves[result].create(
                    source = source, target = target, enPassantTarget = noSquare,
                    moved = piece, captured = noPiece, promoted = noPiece,
                    castled = false, capturedEnPassant = false)
                result += 1

    var targetMask = pawnCaptureAttackTable[enemy][kingSquare] and not occupancy
    while targetMask != 0:
        let target = targetMask.removeTrailingOneBit.Square
        let sourceMask = pawnQuietAttackTable[enemy][target]
        if sourceMask == 0:
            continue
        let source = sourceMask.countTrailingZeroBits.Square
        if (bitAt[source] and position[pawn] and position[us]) != 0:
            moves[result].create(
                source = source, target = target, enPassantTarget = noSquare,
                moved = pawn, captured = noPiece, promoted = noPiece,
                castled = false, capturedEnPassant = false)
            result += 1

        # double pushs
        let doublePushSourceMask = pawnQuietAttackTable[enemy][source]
        if doublePushSourceMask == 0:
            continue
        let doublePushSource = doublePushSourceMask.countTrailingZeroBits.Square
        if (occupancy and bitAt[source]) == 0 and 
        (bitAt[doublePushSource] and pawnHomeRank[us] and position[us] and position[pawn]) != 0:
            moves[result].create(
                source = doublePushSource, target = target, enPassantTarget = source,
                moved = pawn, captured = noPiece, promoted = noPiece,
                castled = false, capturedEnPassant = false)
            result += 1