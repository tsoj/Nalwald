import types
import bitboard
import bitops
import zobristBitmasks
import move
import castling
import utils
import options
import strutils
import castling

type Position* = object
    pieces: array[pawn..king, Bitboard]
    colors: array[white..black, Bitboard]
    enPassantCastling*: Bitboard
    rookSource*: array[white..black, array[queenside..kingside, Square]]
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

func coloredPiece*(position: Position, square: Square): ColoredPiece =
    for color in white..black:
        for piece in pawn..king:
            if (bitAt[square] and position[piece] and position[color]) != 0:
                return ColoredPiece(piece: piece, color: color)
    ColoredPiece(piece: noPiece, color: noColor)

template occupancy*(position: Position): Bitboard =
    position[white] or position[black]

func addPiece*(position: var Position, color: Color, piece: Piece, target: Bitboard) =
    position[piece] = position[piece] or target
    position[color] = position[color] or target

func removePiece*(position: var Position, color: Color, piece: Piece, source: Bitboard) =
    position[piece] = position[piece] and (not source)
    position[color] = position[color] and (not source)

func movePiece*(position: var Position, color: Color, piece: Piece, source, target: Bitboard) =
    position.removePiece(color, piece, source)
    position.addPiece(color, piece, target)

func attackers(position: Position, us, enemy: Color, target: Square): Bitboard =
    let occupancy = position.occupancy
    (
        (bishop.attackMask(target, occupancy) and (position[bishop] or position[queen])) or
        (rook.attackMask(target, occupancy) and (position[rook] or position[queen])) or
        (knight.attackMask(target, occupancy) and position[knight]) or
        (king.attackMask(target, occupancy) and position[king]) or
        (pawnCaptureAttackTable[us][target] and position[pawn])
    ) and position[enemy]

func isAttacked*(position: Position, us, enemy: Color, target: Square): bool =
    position.attackers(us, enemy, target) != 0

func kingSquare*(position: Position, color: Color): Square =
    assert (position[king] and position[color]).countSetBits == 1
    (position[king] and position[color]).countTrailingZeroBits.Square

func inCheck*(position: Position, us, enemy: Color): bool =
    position.isAttacked(us, enemy, position.kingSquare(us))

func isPassedPawn*(position: Position, us, enemy: Color, square: Square): bool =
    (isPassedMask[us][square] and position[pawn] and position[enemy]) == 0

func isPseudoLegal*(position: Position, move: Move): bool =
    if move == noMove:
        return false

    #TODO: fix
    #TODO: test with -d:debug properly enabled

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

    elif move.castled:
        if (position.enPassantCastling and homeRank[us]) == 0:
            return false
        let castlingSide =
            if target == position.rookSource[us][queenside]:
                queenside
            elif target == position.rookSource[us][kingside]:
                kingside
            else:
                return false
        
        let
            kingSource = (position[us] and position[king]).countTrailingZeroBits.Square
            rookSource = position.rookSource[us][castlingSide]

        if (position.enPassantCastling and bitAt[rookSource]) == 0 or
        (blockSensitive(castlingSide, us, kingSource, rookSource) and occupancy) != 0:
            return false

        for checkSquare in checkSensitive[castlingSide][us][kingSource]:
            if position.isAttacked(us, enemy, checkSquare):
                return false
    true

func calculateZobristKey*(position: Position): uint64 =
    result = 0
    for piece in pawn..king:
        var occupancy = position[piece]
        while occupancy != 0:
            let square: Square = occupancy.removeTrailingOneBit.Square
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
        position.removePiece(enemy, pawn, pawnQuietAttackTable[enemy][target])
        position.movePiece(us, pawn, bitAt[source], bitAt[target])

        let capturedSquare = pawnQuietAttackTable[enemy][target].countTrailingZeroBits.Square
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
        let (rookTarget, kingTarget) =
            if target == position.rookSource[us][queenside]:
                (rookTarget[queenside][us], kingTarget[queenside][us])
            else:
                (rookTarget[kingside][us], kingTarget[kingside][us])
        
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

func isLegal*(position: Position, move: Move): bool =
    if not position.isPseudoLegal(move):
        return false
    var newPosition = position
    newPosition.doMove(move)
    return not newPosition.inCheck(position.us, position.enemy)

func addColoredPiece*(position: var Position, coloredPiece: ColoredPiece, square: Square) =
    for color in [white, black]:
        position[color] = position[color] and (not bitAt[square])
    for piece in pawn..king:
        position[piece] = position[piece] and (not bitAt[square])

    position.addPiece(coloredPiece.color, coloredPiece.piece, bitAt[square])

proc toPosition*(fen: string, suppressWarnings = false): Position =
    var fenWords = fen.splitWhitespace()    
    if fenWords.len < 4:
        raise newException(ValueError, "FEN must have at least 4 words")
    if fenWords.len > 6 and not suppressWarnings:
        echo "Warning: FEN shouldn't have more than 6 words"
    while fenWords.len < 6:
        fenWords.add("0")   

    let piecePlacement = fenWords[0]
    let activeColor = fenWords[1]
    let castlingRights = fenWords[2]
    let enPassant = fenWords[3]
    let halfmoveClock = fenWords[4]
    let fullmoveNumber = fenWords[5]

    var currentSquare = a8
    for pieceChar in piecePlacement:
        case pieceChar
        of '/':
            currentSquare = ((currentSquare).int8 - 16).Square
        of '8', '7', '6', '5', '4', '3', '2', '1':
            currentSquare = (currentSquare.int8 + parseInt($pieceChar)).Square
        else:
            if currentSquare > h8 or currentSquare < a1:
                raise newException(ValueError, "FEN piece placement is not correctly formatted: " & $currentSquare)
            try:
                result.addColoredPiece(pieceChar.toColoredPiece, currentSquare)
            except ValueError:
                raise newException(ValueError, "FEN piece placement is not correctly formatted: " &
                        getCurrentExceptionMsg())
            currentSquare = (currentSquare.int8 + 1).Square
    
    # active color
    case activeColor
    of "w", "W":
        result.us = white
        result.enemy = black
    of "b", "B":
        result.us = black
        result.enemy = white
    else:
        raise newException(ValueError, "FEN active color notation does not exist: " & activeColor)

    # castling rights
    result.enPassantCastling = 0
    for castlingChar in castlingRights:
        let castlingChar = case castlingChar:
        of '-':
            continue
        of 'K':
            'H'
        of 'k':
            'h'
        of 'Q':
            'A'
        of 'q':
            'a'
        else:
            castlingChar

        let
            us = if castlingChar.isUpperAscii: white else: black
            kingSquare = (result[us] and result[king]).countTrailingZeroBits.Square
            rookSource = (files[parseEnum[Square](castlingChar.toLowerAscii & "1")] and homeRank[us]).countTrailingZeroBits.Square
            castlingSide = if rookSource < kingSquare: queenside else: kingside
        
        result.enPassantCastling = result.enPassantCastling or bitAt[rookSource]
        result.rookSource[us][castlingSide] = rookSource

    # en passant square
    if enPassant != "-":
        try:
            result.enPassantCastling = result.enPassantCastling or bitAt[parseEnum[Square](enPassant.toLowerAscii)]
        except ValueError:
            raise newException(ValueError, "FEN en passant target square is not correctly formatted: " &
                    getCurrentExceptionMsg())

    # halfmove clock and fullmove number
    try:
        result.halfmoveClock = parseUInt(halfmoveClock).int16
    except ValueError:
        raise newException(ValueError, "FEN halfmove clock is not correctly formatted: " & getCurrentExceptionMsg())

    try:
        result.halfmovesPlayed = parseUInt(fullmoveNumber).int16 * 2
    except ValueError:
        raise newException(ValueError, "FEN fullmove number is not correctly formatted: " & getCurrentExceptionMsg())

    result.zobristKey = result.calculateZobristKey

func fen*(position: Position): string =
    result = ""
    var emptySquareCounter = 0
    for rank in countdown(7, 0):
        for file in 0..7:
            let square = (rank*8 + file).Square
            let coloredPiece = position.coloredPiece(square)
            if coloredPiece.piece != noPiece and coloredPiece.color != noColor:
                if emptySquareCounter > 0:
                    result &= $emptySquareCounter
                    emptySquareCounter = 0
                result &= coloredPiece.notation
            else:
                emptySquareCounter += 1
        if emptySquareCounter > 0:
            result &= $emptySquareCounter
            emptySquareCounter = 0
        if rank != 0:
            result &= "/"
            
    result &= (if position.us == white: " w " else: " b ")

    for color in [white, black]:
        for castlingSide in queenside..kingside:
            let rookSource = position.rookSource[color][castlingSide]
            if (position.enPassantCastling and bitAt[rookSource] and homeRank[color]) != 0:
                result &= ($rookSource)[0]

                if result[^1] == 'h':
                    result[^1] = 'k'
                if result[^1] == 'a':
                    result[^1] = 'q'

                if color == white:
                    result[^1] = result[^1].toUpperAscii
                
    if result.endsWith(' '):
        result &= "-"

    result &= " "

    if (position.enPassantCastling and (ranks[a3] or ranks[a6])) != 0:
        result &= $((position.enPassantCastling and (ranks[a3] or ranks[a6])).countTrailingZeroBits.Square)
    else:
        result &= "-"

    result &= " " & $position.halfmoveClock & " " & $(position.halfmovesPlayed div 2)

func `$`*(position: Position): string =
    result = boardString(proc (square: Square): Option[string] =
        if (bitAt[square] and position.occupancy) != 0:
            return some($position.coloredPiece(square))
        none(string)
    ) & "\n"
    let fenWords = position.fen.splitWhitespace
    for i in 1..<fenWords.len:
        result &= fenWords[i] & " "

func debugString*(position: Position): string =    
    for piece in pawn..king:
        result &= $piece & ":\n"
        result &= position[piece].bitboardString & "\n"
    for color in white..black:
        result &= $color & ":\n"
        result &= position[color].bitboardString & "\n"
    result &= "enPassantCastling:\n"
    result &= position.enPassantCastling.bitboardString & "\n"
    result &= "us: " & $position.us & ", enemy: " & $position.enemy & "\n"
    result &= "halfmovesPlayed: " & $position.halfmovesPlayed & ", halfmoveClock: " & $position.halfmoveClock & "\n"
    result &= "zobristKey: " & $position.zobristKey & "\n"
    result &= "rookSource: " & $position.rookSource

func toMove*(s: string, position: Position): Move =
    let us = position.us

    doAssert s.len == 4 or s.len == 5

    let
        source = parseEnum[Square](s[0..1])
        target = parseEnum[Square](s[2..3])

    let promoted = if s.len == 5: s[4].toColoredPiece.piece else: noPiece
    let moved = position.coloredPiece(source).piece
    let capturedEnPassant = moved == pawn and (bitAt[target] and position.enPassantCastling and (ranks[a3] or ranks[a6])) != 0
    let captured = if capturedEnPassant: pawn else: position.coloredPiece(target).piece

    let enPassantTarget = if moved == pawn and captured == noPiece and (bitAt[target] and pawnQuietAttackTable[us][source]) == 0:
        pawnQuietAttackTable[us][source].countTrailingZeroBits.Square
    else:
        noSquare

    let castlingSide = if target == kingTarget[queenside][us] or target == position.rookSource[us][queenside]:
        queenside
    else:
        kingside
    let castled = moved == king and
    (position.enPassantCastling and homeRank[us]) != 0 and
    (target == kingTarget[castlingSide][us] or target == position.rookSource[us][castlingSide])

    result.create(
        source = source,
        target = if castled: position.rookSource[us][castlingSide] else: target,
        enPassantTarget = enPassantTarget,
        moved = moved,
        captured = if castled: noPiece else: captured,
        promoted = promoted,
        castled = castled,
        capturedEnPassant = capturedEnPassant
    )

    doAssert position.isLegal(result)
    
func gamePhase*(position: Position): GamePhase =
    position.occupancy.countSetBits.GamePhase

func material*(position: Position): Value =
    result = 0
    for piece in pawn..king:
        result += (position[piece] and position[position.us]).countSetBits.Value * values[piece]
        result -= (position[piece] and position[position.enemy]).countSetBits.Value * values[piece]

func absoluteMaterial*(position: Position): Value =
    result = position.material
    if position.us == black:
        result = -result

func insufficientMaterial*(position: Position): bool =
    (position[pawn] or position[rook] or position[queen]) == 0 and (position[bishop] or position[knight]).countSetBits <= 1

func flipColors*(position: Position): Position =
    result = Position(
        colors: [white: position[black].mirror, black: position[white].mirror],
        enPassantCastling: position.enPassantCastling.mirror,
        us: position.enemy, enemy: position.us,
        halfmovesPlayed: position.halfmovesPlayed,
        halfmoveClock: position.halfmoveClock
    )
    for piece in pawn..king:
        result[piece] = position[piece].mirror
    result.zobristKey = result.calculateZobristKey