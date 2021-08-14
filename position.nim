import
    types,
    bitboard,
    move,
    zobristBitmasks,
    castling,
    bitops

type Position* = object
    pieces: array[pawn..king, Bitboard]
    colors: array[white..black, Bitboard]
    enPassantCastling*: Bitboard
    rookSource*: array[white..black, array[CastlingSide, Square]]
    zobristKey*: uint64
    us*, enemy*: Color
    halfmovesPlayed*: int16
    halfmoveClock*: int16

template `[]`*(position: Position, piece: Piece): Bitboard =
    position.pieces[piece]

template `[]=`*(position: var Position, piece: Piece, bitboard: Bitboard) =
    position.pieces[piece] = bitboard

template `[]`*(position: Position, color: Color): Bitboard =
    position.colors[color]

template `[]=`*(position: var Position, color: Color, bitboard: Bitboard) =
    position.colors[color] = bitboard

func addPiece*(position: var Position, color: Color, piece: Piece, target: Bitboard) =
    position[piece] = position[piece] or target
    position[color] = position[color] or target

func removePiece*(position: var Position, color: Color, piece: Piece, source: Bitboard) =
    position[piece] = position[piece] and (not source)
    position[color] = position[color] and (not source)

func movePiece*(position: var Position, color: Color, piece: Piece, source, target: Bitboard) =
    position.removePiece(color, piece, source)
    position.addPiece(color, piece, target)

func castlingSide*(position: Position, move: Move): CastlingSide =
    if move.target == position.rookSource[position.us][queenside]:
        return queenside
    kingside

func occupancy*(position: Position): Bitboard =
    position[white] or position[black]

func attackers(position: Position, us, enemy: Color, target: Square): Bitboard =
    let occupancy = position.occupancy
    (
        (bishop.attackMask(target, occupancy) and (position[bishop] or position[queen])) or
        (rook.attackMask(target, occupancy) and (position[rook] or position[queen])) or
        (knight.attackMask(target, occupancy) and position[knight]) or
        (king.attackMask(target, occupancy) and position[king]) or
        (attackTablePawnCapture[us][target] and position[pawn])
    ) and position[enemy]

func isAttacked*(position: Position, us, enemy: Color, target: Square): bool =
    position.attackers(us, enemy, target) != 0

func isPseudoLegal*(position: Position, move: Move): bool =
    if move == noMove:
        return false

    let
        target = move.target
        source = move.source
        moved = move.moved
        captured = move.captured
        enPassantTarget = move.enPassantTarget
        capturedEnPassant = move.capturedEnPassant
        us = position.us
        enemy = position.enemy
        occupancy = position.occupancy
    assert source != noSquare and target != noSquare and moved != noPiece

    if (bitAt[source] and position[us] and position[moved]) == 0:
        return false
    
    if (bitAt[target] and position[us]) != 0 and not move.castled:
        return false

    if captured != noPiece and (bitAt[target] and position[enemy] and position[captured]) == 0 and not capturedEnPassant:
        return false

    if captured == noPiece and  (bitAt[target] and position[enemy]) != 0:
        return false

    if moved == pawn and captured == noPiece and 
    ((occupancy and bitAt[target]) != 0 or (enPassantTarget != noSquare and (bitAt[enPassantTarget] and occupancy) != 0)):
        return false

    if capturedEnPassant and (bitAt[target] and position.enPassantCastling and not(ranks[a1] or ranks[a8])) == 0:
        return false

    if (moved == bishop or moved == rook or moved == queen) and
    (bitAt[target] and moved.attackMask(source, occupancy)) == 0:
        return false

    if moved == pawn:
        if captured != noPiece and (bitAt[target] and attackTablePawnCapture[us][source]) == 0:
            return false
        elif captured == noPiece and (bitAt[target] and attackTablePawnQuiet[us][source]) == 0 and
        (
            (attackTablePawnQuiet[enemy][target] and attackTablePawnQuiet[us][source]) == 0 or
            (occupancy and attackTablePawnQuiet[us][source]) != 0
        ):
            return false

    if move.castled:
        if (position.enPassantCastling and homeRank[us]) == 0:
            return false

        if not (target in position.rookSource[us]):
            return false

        let castlingSide = position.castlingSide(move)
        
        let
            kingSource = (position[us] and position[king]).toSquare
            rookSource = position.rookSource[us][castlingSide]

        if (position.enPassantCastling and bitAt[rookSource]) == 0 or
        (blockSensitive(us, castlingSide, kingSource, rookSource) and occupancy) != 0:
            return false

        for checkSquare in checkSensitive[us][castlingSide][kingSource]:
            if position.isAttacked(us, enemy, checkSquare):
                return false
    true

func calculateZobristKey*(position: Position): uint64 =
    result = 0
    for piece in pawn..king:
        for square in position[piece]:
            result = result xor (if (position[white] and bitAt[square]) != 0:
                zobristColorBitmasks[white][square]
            else:
                zobristColorBitmasks[black][square]
            ) xor zobristPieceBitmasks[piece][square]
    result = result xor position.enPassantCastling xor zobristSideToMoveBitmasks[position.us]

func doMove*(position: var Position, move: Move) =
    assert position.isPseudoLegal(move)
    let
        target = move.target
        source = move.source
        moved = move.moved
        captured = move.captured
        promoted = move.promoted
        enPassantTarget = move.enPassantTarget
        us = position.us
        enemy = position.enemy

    position.zobristKey = position.zobristKey xor cast[uint64](position.enPassantCastling)
    position.enPassantCastling = position.enPassantCastling and (ranks[a1] or ranks[a8])
    position.enPassantCastling = position.enPassantCastling and (not (bitAt[source] or bitAt[target]))
    if enPassantTarget != noSquare:
        position.enPassantCastling = position.enPassantCastling or bitAt[enPassantTarget]
    if moved == king:
        position.enPassantCastling = position.enPassantCastling and not homeRank[us]
    position.zobristKey = position.zobristKey xor cast[uint64](position.enPassantCastling)

    # en passant
    if move.capturedEnPassant:
        position.removePiece(enemy, pawn, attackTablePawnQuiet[enemy][target])
        position.movePiece(us, pawn, bitAt[source], bitAt[target])

        let capturedSquare = attackTablePawnQuiet[enemy][target].toSquare
        position.zobristKey = position.zobristKey xor zobristPieceBitmasks[pawn][capturedSquare]
        position.zobristKey = position.zobristKey xor zobristColorBitmasks[enemy][capturedSquare]
    # removing captured piece
    elif captured != noPiece:
        position.removePiece(enemy, captured, bitAt[target])
        position.zobristKey = position.zobristKey xor zobristPieceBitmasks[captured][target]
        position.zobristKey = position.zobristKey xor zobristColorBitmasks[enemy][target]

    # castling
    if move.castled:
        let
            rookSource = target
            kingSource = source
            castlingSide = position.castlingSide(move)
            rookTarget = rookTarget[us][castlingSide]
            kingTarget = kingTarget[us][castlingSide]
        
        position.removePiece(us, king, bitAt[kingSource])
        position.removePiece(us, rook, bitAt[rookSource])

        for (piece, source, target) in [
            (king, kingSource, kingTarget),
            (rook, rookSource, rookTarget)
        ]:
            position.addPiece(us, piece, bitAt[target])
            position.zobristKey = position.zobristKey xor zobristPieceBitmasks[piece][source]
            position.zobristKey = position.zobristKey xor zobristPieceBitmasks[piece][target]
            position.zobristKey = position.zobristKey xor zobristColorBitmasks[us][source]
            position.zobristKey = position.zobristKey xor zobristColorBitmasks[us][target]

    # moving piece
    else:
        position.zobristKey = position.zobristKey xor zobristColorBitmasks[us][source]
        position.zobristKey = position.zobristKey xor zobristColorBitmasks[us][target]
        position.zobristKey = position.zobristKey xor zobristPieceBitmasks[moved][source]
        if promoted != noPiece:
            position.removePiece(us, moved, bitAt[source])
            position.addPiece(us, promoted, bitAt[target])
            position.zobristKey = position.zobristKey xor zobristPieceBitmasks[promoted][target]
        else:
            position.movePiece(us, moved, bitAt[source], bitAt[target])
            position.zobristKey = position.zobristKey xor zobristPieceBitmasks[moved][target]

    position.halfmovesPlayed += 1 
    position.halfmoveClock += 1
    if moved == pawn or captured != noPiece:
        position.halfmoveClock = 0

    position.enemy = position.us
    position.us = position.us.opposite
    
    position.zobristKey = position.zobristKey xor zobristSideToMoveBitmasks[white]
    position.zobristKey = position.zobristKey xor zobristSideToMoveBitmasks[black]

func doNullMove*(position: var Position) =
    position.zobristKey = position.zobristKey xor position.enPassantCastling
    position.enPassantCastling = position.enPassantCastling and (ranks[a1] or ranks[a8])
    position.zobristKey = position.zobristKey xor position.enPassantCastling

    position.zobristKey = position.zobristKey xor zobristSideToMoveBitmasks[white]
    position.zobristKey = position.zobristKey xor zobristSideToMoveBitmasks[black]

    position.enemy = position.us
    position.us = position.us.opposite

func kingSquare*(position: Position, color: Color): Square =
    assert (position[king] and position[color]).countSetBits == 1
    (position[king] and position[color]).toSquare

func inCheck*(position: Position, us, enemy: Color): bool =
    position.isAttacked(us, enemy, position.kingSquare(us))

func isLegal*(position: Position, move: Move): bool =
    if not position.isPseudoLegal(move):
        return false
    var newPosition = position
    newPosition.doMove(move)
    return not newPosition.inCheck(position.us, position.enemy)

func coloredPiece*(position: Position, square: Square): ColoredPiece =
    for color in white..black:
        for piece in pawn..king:
            if (bitAt[square] and position[piece] and position[color]) != 0:
                return ColoredPiece(piece: piece, color: color)
    ColoredPiece(piece: noPiece, color: noColor)

func addColoredPiece*(position: var Position, coloredPiece: ColoredPiece, square: Square) =
    for color in [white, black]:
        position[color] = position[color] and (not bitAt[square])
    for piece in pawn..king:
        position[piece] = position[piece] and (not bitAt[square])

    position.addPiece(coloredPiece.color, coloredPiece.piece, bitAt[square])

func isPassedPawn*(position: Position, us, enemy: Color, square: Square): bool =
    (isPassedMask[us][square] and position[pawn] and position[enemy]) == 0

func gamePhase*(position: Position): GamePhase =
    position.occupancy.countSetBits.GamePhase
