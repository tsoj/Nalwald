import types
import options
import strutils
import atomics
import times
import os
import math

func boardString*(f: proc(square: Square): Option[string]): string =
    result = " _ _ _ _ _ _ _ _\n"
    for rank in countdown(7, 0):
        for file in 0..7:
            result &= "|"
            let s = f((8*rank + file).Square)
            if s.isSome:
                result &= s.get()
            else:
                result &= "_"
        result &= "|" & intToStr(rank + 1) & "\n"
    result &= " A B C D E F G H"

func notation*(piece: Piece): string =
    const t = [pawn: "p", knight: "n", bishop: "b", rook: "r", queen: "q", king: "k", noPiece: "-"]
    t[piece]

func notation*(coloredPiece: ColoredPiece): string =
    result = $coloredPiece.piece
    if coloredPiece.color == white:
        result = result.toUpperAscii

func `$`*(coloredPiece: ColoredPiece): string =
    const t = [
        white: [pawn: "♟︎", knight: "♞", bishop: "♝", rook: "♜", queen: "♛", king: "♚"],
        black: [pawn: "♙", knight: "♘", bishop: "♗", rook: "♖", queen: "♕", king: "♔"]
        ]
    if coloredPiece.piece == noPiece or coloredPiece.color == noColor:
        return " "
    return t[coloredPiece.color][coloredPiece.piece]

func toColoredPiece*(s: char): ColoredPiece =
    var piece: Piece
    case s
    of 'P', 'p':
        piece = pawn
    of 'N', 'n':
        piece = knight
    of 'B', 'b':
        piece = bishop
    of 'R', 'r':
        piece = rook
    of 'Q', 'q':
        piece = queen
    of 'K', 'k':
        piece = king
    else:
        raise newException(ValueError, "Piece notation doesn't exists: " & s)

    let color = if s.isLowerAscii: black else: white
    ColoredPiece(color: color, piece: piece)

const mirrorTable = block:
    var table: array[Square, Square]
    for s in a1..h8:
        table[s] = ((7 - s.int8 div 8) * 8 + s.int8 mod 8).Square
    table
func mirror*(square: Square): Square =
    mirrorTable[square]

func interpolate*[T](gamePhase: GamePhase, forOpening, forEndgame: T): T =
    result = forOpening*(gamePhase - GamePhase.low).T + forEndgame*(GamePhase.high - gamePhase).T
    when T is SomeInteger:
        result = result div (GamePhase.high - GamePhase.low).T
    else:
        result = result / (GamePhase.high - GamePhase.low).T

proc stopwatch*(flag: ptr Atomic[bool], duration: Duration): bool =
    let start = now()
    while not flag[].load:
        sleep(10)
        if now() - start >= duration:
            flag[].store(true)

func winningProbability*(centipawn: Value): float =
    1.0/(1.0 + pow(10.0, -(centipawn.float/400.0)))

func winningProbabilityDerivative*(centipawn: Value): float =
    (ln(10.0) * pow(2.0, -2.0 - (centipawn.float/400.0)) * pow(5.0, -(centipawn.float/400.0))) /
    pow(1.0 + pow(10.0, -(centipawn.float/400.0)) , 2.0)

