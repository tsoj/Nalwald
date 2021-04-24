import types
import position
import movegen
import move
import utils
import strutils
import bitboard
import castling

func getMoveFromSAN*(position: Position, s: string): Move =
    # TODO error handling
    # TODO test for bugs

    if (s.len >= 5 and s[0..4] == "O-O-O") or (s.len >= 3 and s[0..2] == "O-O"):
        let castlingSide = if (s.len >= 5 and s[0..4] == "O-O-O"): queenside else: kingside
        result.create(
            source = kingSource[position.us], target = kingTarget[castlingSide][position.us], enPassantTarget = noSquare,
            moved = king, captured = noPiece, promoted = noPiece,
            castled = true, capturedEnPassant = false)
        return result

    var s = s
    doAssert s.len >= 1
    if not s[0].isUpperAscii:
        s = ($pawn).toUpperAscii & s

    doAssert s.len >= 1
    let moved = s[0].toColoredPiece.piece
    s.delete(0,0)

    if s[^1] == '#' or s[^1] == '+':
        s.delete(s.len - 1, s.len - 1)

    doAssert s.len >= 2
    let promoted = block:
        var p = noPiece
        if s[^2] == '=':
            p = s[^1].toColoredPiece.piece
            s.delete(s.len - 2, s.len - 1)
        p

    let isCapture = block:
        let i = s.find('x')
        var b = false
        if i != -1:
            s.delete(i,i)
            b = true
        b

    doAssert s.len >= 2
    let target = parseEnum[Square](s[^2..^1])

    let sourceBitMask = block:
        var sourceBitMask = not 0.Bitboard
        if s.len == 1:
            if s[0].isAlphaAscii:
                sourceBitMask = files[parseEnum[Square](s & "1")]
            else:
                sourceBitMask = files[parseEnum[Square]("a" & s)]
        elif s.len == 2:
            sourceBitMask = bitAt[parseEnum[Square](s)]
        sourceBitMask

    let legalMoves = position.legalMoves

    var numPossibleMoves = 0
    for move in legalMoves:
        if move.moved == moved and
        move.promoted == promoted and
        move.target == target and
        (bitAt[move.source] and sourceBitMask) != 0:
            numPossibleMoves += 1
            doAssert numPossibleMoves <= 1
            doAssert (move.captured != noPiece) == isCapture
            result = move
    doAssert numPossibleMoves == 1



    

    
    



