import
    types,
    position,
    positionUtils,
    move,
    utils,
    bitboard,
    castling

import std/[
    strutils,
    strformat,
    tables,
    sugar
]

func validSANMove(position: Position, move: Move, san: string): bool =


    if san == "O-O":
        return move.castled and files[move.target] == files[kingTarget[white][kingside]]
    if san == "O-O-O":
        return move.castled and files[move.target] == files[kingTarget[white][queenside]]

    var san = san
    doAssert san.len > 0
    
    if not san[0].isUpperAscii:
        san = "P" & san
    let moved = san[0].toColoredPiece.piece
    san = san[1..^1]
    

    let isCapture = "x" in san

    san = san.replace("+")
    san = san.replace("#")
    san = san.replace("x")

    let promoted = if "=" in san:
        doAssert san.len >= 2 and san[^2] == '='
        san = san.replace("=")
        san[^1].toColoredPiece.piece
    else:
        noPiece

    doAssert san.len >= 2
    let target = parseEnum[Square] san[^2..^1]

    let sourceRank = if san.len >= 1 and san[1] in "12345678":
        ranks[parseEnum[Square]("a" & san[1])]
    else:
        not 0.Bitboard

    let sourceFile = if san.len >= 1 and san[0] in "abcdefgh":
        files[parseEnum[Square](san[0] & "1")]
    else:
        not 0.Bitboard

    return move.moved == moved and
    (move.captured != noPiece) == isCapture and
    move.promoted == promoted and
    move.target == target and
    (sourceRank and sourceFile and move.source.toBitboard) != 0
        
func moveFromSANMove(position: Position, sanMove: string): Move =
    result = noMove
    for move in position.legalMoves:
        if validSANMove(position, move, sanMove):
            doAssert result == noMove, fmt"Ambiguous SAN move notation: {sanMove} (possible moves: {result}, {move}"
            result = move

func popFront(s: var string): char =
    doAssert s.len >= 1
    result = s[0]
    if s.len == 1:
        s = ""
    else:
        s = s[1..^1]

func parseTags(pgn: string): tuple[pgn: string, tags: Table[string, string]] =
    var
        pgn = pgn
        insideTag = false
        insideQuote = false
        currentKey = ""
        currentValue = ""

    while pgn.len >= 1:
        var c = pgn.popFront

        if insideQuote:
            if c == '"':

                while currentKey.len > 0 and currentKey[0].isSpaceAscii:
                    discard currentKey.popFront
                while currentKey.len > 0 and currentKey[^1].isSpaceAscii:
                    currentKey.setLen currentKey.len - 1
                doAssert currentKey notin result.tags, "Trying to add tag multiple times: " & currentKey
                result.tags[currentKey] = currentValue
                
                currentKey = ""
                currentValue = ""
                insideQuote = false
                continue

            if c == '\\' and pgn.len >= 1 and pgn[0] in ['\\', '"']:
                c = pgn.popFront
                doAssert c in ['\\', '"']
            currentValue &= c

        elif insideTag:
            if c == '"':
                insideQuote = true
            elif c == ']':
                insideTag = false
            else:
                currentKey &= c

        elif c == '[':
            insideTag = true
        else:
            result.pgn &= c

func removeComments(pgn: string): string =
    var
        insideBraceComment = false
        insideLineComment = false
    for c in pgn:
        if insideLineComment:
            insideLineComment = c != '\n'
        elif insideBraceComment:
            insideBraceComment = c != '}'
        elif c == ';':
            insideLineComment = true
        elif c == '{':
            insideBraceComment = true
        else:
            result &= c
            
func parsePGN(pgn: string): tuple[tags: Table[string, string], startPosition: Position, moves: seq[Move]] =
    
    discard