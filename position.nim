import
    types,
    bitboard,
    move,
    zobristBitmasks,
    castling

import std/[streams]
    
export types, bitboard, move

type Position* = object
    pieces: array[pawn..king, Bitboard]
    colors: array[white..black, Bitboard]
    enPassantCastling*: Bitboard
    rookSource*: array[white..black, array[CastlingSide, Square]]
    zobristKey*: ZobristKey
    us*: Color
    halfmovesPlayed*: int16
    halfmoveClock*: int16

func enemy*(position: Position): Color =
    position.us.opposite

func `[]`*(position: Position, piece: Piece): Bitboard {.inline.} =
    position.pieces[piece]

func `[]=`*(position: var Position, piece: Piece, bitboard: Bitboard) {.inline.} =
    position.pieces[piece] = bitboard

func `[]`*(position: Position, color: Color): Bitboard {.inline.} =
    position.colors[color]

func `[]=`*(position: var Position, color: Color, bitboard: Bitboard) {.inline.} =
    position.colors[color] = bitboard

func `[]`*(position: Position, piece: Piece, color: Color): Bitboard {.inline.} =
    position[color] and position[piece]
func `[]`*(position: Position, color: Color, piece: Piece): Bitboard {.inline.} =
    position[color] and position[piece]

func addPiece*(position: var Position, color: Color, piece: Piece, target: Square) {.inline.} =
    let bit = target.toBitboard
    position[piece] = position[piece] or bit
    position[color] = position[color] or bit

func removePiece*(position: var Position, color: Color, piece: Piece, source: Square) {.inline.} =
    let bit = not source.toBitboard
    position[piece] = position[piece] and bit
    position[color] = position[color] and bit

func movePiece*(position: var Position, color: Color, piece: Piece, source, target: Square) {.inline.} =
    position.removePiece(color, piece, source)
    position.addPiece(color, piece, target)

func castlingSide*(position: Position, move: Move): CastlingSide =
    if move.target == position.rookSource[position.us][queenside]:
        return queenside
    kingside

func occupancy*(position: Position): Bitboard =
    position[white] or position[black]

func attackers*(position: Position, us: Color, target: Square): Bitboard =
    let
        enemy = us.opposite
        occupancy = position.occupancy
    (
        (bishop.attackMask(target, occupancy) and (position[bishop] or position[queen])) or
        (rook.attackMask(target, occupancy) and (position[rook] or position[queen])) or
        (knight.attackMask(target, occupancy) and position[knight]) or
        (king.attackMask(target, occupancy) and position[king]) or
        (attackTablePawnCapture[us][target] and position[pawn])
    ) and position[enemy]

func isAttacked*(position: Position, us: Color, target: Square): bool =
    position.attackers(us, target) != 0

func isPseudoLegal*(position: Position, move: Move): bool =
    if move == noMove:
        return false

    let
        target = move.target
        source = move.source
        moved = move.moved
        captured = move.captured
        promoted = move.promoted
        enPassantTarget = move.enPassantTarget
        capturedEnPassant = move.capturedEnPassant
        us = position.us
        enemy = position.enemy
        occupancy = position.occupancy

    if moved notin pawn..king or
    source notin a1..h8 or
    target notin a1..h8:
        return false

    # check that moved is okay
    if (source.toBitboard and position[us] and position[moved]) == 0:
        return false
    
    # check that target is okay, but handle castle case extra
    if (target.toBitboard and position[us]) != 0 and not move.castled:
        return false

    # check that captured is okay, but handle en passant case extra
    if captured != noPiece and (target.toBitboard and position[enemy] and position[captured]) == 0 and not capturedEnPassant:
        return false
    if captured == noPiece and (target.toBitboard and position[enemy]) != 0:
        return false
    # handle the captured en passant case
    if capturedEnPassant:
        if (target.toBitboard and position.enPassantCastling and not(ranks[a1] or ranks[a8])) == 0:
            return false
        if (target.toBitboard and occupancy) != 0:
            return false

    if (moved == bishop or moved == rook or moved == queen) and
    (target.toBitboard and moved.attackMask(source, occupancy)) == 0:
        return false

    if moved == pawn:
        if captured != noPiece and (target.toBitboard and attackTablePawnCapture[us][source]) == 0:
            return false
        elif captured == noPiece:
            if target.toBitboard != attackTablePawnQuiet[us][source]:
                if (occupancy and attackTablePawnQuiet[us][source]) != 0:
                    return false
                if enPassantTarget notin a1..h8:
                    return false
                if (enPassantTarget.toBitboard and attackTablePawnQuiet[enemy][target] and attackTablePawnQuiet[us][source]) == 0:
                    return false
            elif enPassantTarget != noSquare:
                return false

    if promoted != noPiece:
        if moved != pawn:
            return false
        if promoted notin knight..queen:
            return false
        if (target.toBitboard and (ranks[a1] or ranks[a8])) == 0:
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

        if (position.enPassantCastling and rookSource.toBitboard) == 0 or
        (blockSensitive(us, castlingSide, kingSource, rookSource) and occupancy) != 0:
            return false

        for checkSquare in checkSensitive[us][castlingSide][kingSource]:
            if position.isAttacked(us, checkSquare):
                return false

    assert source != noSquare and target != noSquare and moved != noPiece
    true

func calculateZobristKey*(position: Position): ZobristKey =
    result = 0
    for piece in pawn..king:
        for square in position[piece]:
            result = result xor (if (position[white] and square.toBitboard) != 0:
                zobristPieceBitmasks[white][piece][square]
            else:
                zobristPieceBitmasks[black][piece][square]
            )
    result = result xor position.enPassantCastling xor zobristSideToMoveBitmasks[position.us]

func doMoveInPlace*(position: var Position, move: Move) {.inline.} =
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

    position.zobristKey = position.zobristKey xor cast[ZobristKey](position.enPassantCastling)
    position.enPassantCastling = position.enPassantCastling and (ranks[a1] or ranks[a8])
    position.enPassantCastling = position.enPassantCastling and not (source.toBitboard or target.toBitboard)
    if enPassantTarget != noSquare:
        position.enPassantCastling = position.enPassantCastling or enPassantTarget.toBitboard
    if moved == king:
        position.enPassantCastling = position.enPassantCastling and not homeRank[us]
    position.zobristKey = position.zobristKey xor cast[ZobristKey](position.enPassantCastling)

    # en passant
    if move.capturedEnPassant:
        position.removePiece(enemy, pawn, attackTablePawnQuiet[enemy][target].toSquare)
        position.movePiece(us, pawn, source, target)

        let capturedSquare = attackTablePawnQuiet[enemy][target].toSquare
        position.zobristKey = position.zobristKey xor zobristPieceBitmasks[enemy][pawn][capturedSquare]
    # removing captured piece
    elif captured != noPiece:
        position.removePiece(enemy, captured, target)
        position.zobristKey = position.zobristKey xor zobristPieceBitmasks[enemy][captured][target]

    # castling
    if move.castled:
        let
            rookSource = target
            kingSource = source
            castlingSide = position.castlingSide(move)
            rookTarget = rookTarget[us][castlingSide]
            kingTarget = kingTarget[us][castlingSide]
        
        position.removePiece(us, king, kingSource)
        position.removePiece(us, rook, rookSource)

        for (piece, source, target) in [
            (king, kingSource, kingTarget),
            (rook, rookSource, rookTarget)
        ]:
            position.addPiece(us, piece, target)
            position.zobristKey = position.zobristKey xor zobristPieceBitmasks[us][piece][source]
            position.zobristKey = position.zobristKey xor zobristPieceBitmasks[us][piece][target]

    # moving piece
    else:
        position.zobristKey = position.zobristKey xor zobristPieceBitmasks[us][moved][source]
        if promoted != noPiece:
            position.removePiece(us, moved, source)
            position.addPiece(us, promoted, target)
            position.zobristKey = position.zobristKey xor zobristPieceBitmasks[us][promoted][target]
        else:
            position.movePiece(us, moved, source, target)
            position.zobristKey = position.zobristKey xor zobristPieceBitmasks[us][moved][target]

    position.halfmovesPlayed += 1 
    position.halfmoveClock += 1
    if moved == pawn or captured != noPiece:
        position.halfmoveClock = 0
    
    position.us = position.us.opposite
    
    position.zobristKey = position.zobristKey xor zobristSideToMoveBitmasks[white]
    position.zobristKey = position.zobristKey xor zobristSideToMoveBitmasks[black]

func doMove*(position: Position, move: Move): Position {.inline.} =
    result = position
    result.doMoveInPlace(move)

func doNullMoveInPlace*(position: var Position) =
    position.zobristKey = position.zobristKey xor position.enPassantCastling
    position.enPassantCastling = position.enPassantCastling and (ranks[a1] or ranks[a8])
    position.zobristKey = position.zobristKey xor position.enPassantCastling

    position.zobristKey = position.zobristKey xor zobristSideToMoveBitmasks[white]
    position.zobristKey = position.zobristKey xor zobristSideToMoveBitmasks[black]

    position.halfmoveClock = 0

    position.us = position.us.opposite

func doNullMove*(position: Position): Position =
    result = position
    result.doNullMoveInPlace()

func kingSquare*(position: Position, color: Color): Square =
    assert (position[king] and position[color]).countSetBits == 1
    (position[king] and position[color]).toSquare

func inCheck*(position: Position, us: Color): bool =
    position.isAttacked(us, position.kingSquare(us))

func isLegal*(position: Position, move: Move): bool =
    if not position.isPseudoLegal(move):
        return false
    let newPosition = position.doMove(move)
    return not newPosition.inCheck(position.us)

func coloredPiece*(position: Position, square: Square): ColoredPiece =
    for color in white..black:
        for piece in pawn..king:
            if (square.toBitboard and position[piece] and position[color]) != 0:
                return ColoredPiece(piece: piece, color: color)
    ColoredPiece(piece: noPiece, color: noColor)

func addColoredPiece*(position: var Position, coloredPiece: ColoredPiece, square: Square) =
    for color in [white, black]:
        position[color] = position[color] and not square.toBitboard
    for piece in pawn..king:
        position[piece] = position[piece] and not square.toBitboard

    position.addPiece(coloredPiece.color, coloredPiece.piece, square)

func isPassedPawn*(position: Position, us: Color, square: Square): bool {.inline.} =
    (isPassedMask[us][square] and position[pawn] and position[us.opposite]) == 0

func isPassedPawnMove*(newPosition: Position, move: Move): bool =
    move.moved == pawn and newPosition.isPassedPawn(newPosition.enemy, move.target)

func gamePhase*(position: Position): GamePhase =
    position.occupancy.countSetBits.GamePhase

func mirrorVertically*(position: Position, skipZobristKey: static bool = false): Position =
    
    result.halfmovesPlayed = position.halfmovesPlayed
    result.halfmoveClock = position.halfmoveClock
    
    for piece, bitboard in position.pieces:
        result[piece] = bitboard.mirrorVertically
    for color, bitboard in position.colors:
        result[color.opposite] = bitboard.mirrorVertically
    
    result.enPassantCastling = position.enPassantCastling.mirrorVertically
    result.us = position.us.opposite

    result.rookSource = [
        white: position.rookSource[black],
        black: position.rookSource[white]
    ]
    for color in white..black:
        for castlingSide in queenside..kingside:
            result.rookSource[color][castlingSide] = result.rookSource[color][castlingSide].mirrorVertically
    
    when not skipZobristKey:
        result.zobristKey = position.calculateZobristKey

func mirrorHorizontally*(position: Position, skipZobristKey: static bool = false): Position =
    
    result.halfmovesPlayed = position.halfmovesPlayed
    result.halfmoveClock = position.halfmoveClock
    
    for piece, bitboard in position.pieces:
        result[piece] = bitboard.mirrorHorizontally
    for color, bitboard in position.colors:
        result[color] = bitboard.mirrorHorizontally
    
    result.enPassantCastling = position.enPassantCastling.mirrorHorizontally
    result.us = position.us

    for color in white..black:
        result.rookSource[color][kingside] = position.rookSource[color][queenside].mirrorHorizontally
        result.rookSource[color][queenside] = position.rookSource[color][kingside].mirrorHorizontally
    
    when not skipZobristKey:
        result.zobristKey = position.calculateZobristKey

func rotate*(position: Position, skipZobristKey: static bool = false): Position =
    result = position.mirrorHorizontally(skipZobristKey = true).mirrorVertically(skipZobristKey = true)
    
    when not skipZobristKey:
        result.zobristKey = position.calculateZobristKey

proc writePosition*(stream: Stream, position: Position) =
    for pieceBitboard in position.pieces:
        stream.write pieceBitboard.uint64
    for colorBitboard in position.colors:
        stream.write colorBitboard.uint64

    stream.write position.enPassantCastling.uint64
    
    for color in white..black:
        for castlingSide in CastlingSide:
            stream.write position.rookSource[color][castlingSide].uint8
    
    stream.write position.zobristKey.uint64
    stream.write position.us.uint8
    stream.write position.halfmovesPlayed
    stream.write position.halfmoveClock
    
proc readPosition*(stream: Stream): Position =
    for pieceBitboard in result.pieces.mitems:
        pieceBitboard = stream.readUint64.Bitboard
    for colorBitboard in result.colors.mitems:
        colorBitboard = stream.readUint64.Bitboard

    result.enPassantCastling = stream.readUint64.Bitboard
    
    for color in white..black:
        for castlingSide in CastlingSide:
            result.rookSource[color][castlingSide] = stream.readUint8.Square
    
    result.zobristKey = stream.readUint64.ZobristKey
    result.us = stream.readUint8.Color
    result.halfmovesPlayed = stream.readInt16
    result.halfmoveClock = stream.readInt16

