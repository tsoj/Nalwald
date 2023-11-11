import
    types

import std/[
    options,
    strutils,
    atomics,
    times,
    os,
    osproc
]

const megaByteToByte* = 1_048_576

func boardString*(f: proc(square: Square): Option[string] {.noSideEffect.}): string =
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
    result = coloredPiece.piece.notation
    if coloredPiece.color == white:
        result = result.toUpperAscii

func `$`*(coloredPiece: ColoredPiece): string =
    const t = [
        white: [pawn: "♟", knight: "♞", bishop: "♝", rook: "♜", queen: "♛", king: "♚"],
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

func interpolate*[T](gamePhase: GamePhase, forOpening, forEndgame: T): T =

    type I = (when T is SomeInteger: BiggestInt else: float)

    var tmp: I
    tmp = forOpening.I*(gamePhase - GamePhase.low).I + forEndgame.I*(GamePhase.high - gamePhase).I
    when T is SomeInteger:
        tmp = tmp div (GamePhase.high - GamePhase.low).I
        static: doAssert(
            GamePhase.high - GamePhase.low == 32,
            "This makes sure that this division can be done using bitshifts")
    else:
        tmp = tmp / (GamePhase.high - GamePhase.low).T

    result = tmp.T

proc stopwatch*(flag: ptr Atomic[bool], duration: Duration): bool =
    const sleepTimeMs = 5
    let
        start = now()
        duration = duration - initDuration(milliseconds = sleepTimeMs)
    while not flag[].load:
        if now() - start >= duration:
            flag[].store(true)
        sleep(sleepTimeMs)

func clampToType*[In, Out](x: In, OutType: typedesc[Out]): Out =
    x.clamp(OutType.low.In, OutType.high.In).Out

proc getCpuInfo*(): string =
    when defined(posix):
        var cpuName = execCmdEx("""
        cat /proc/cpuinfo | awk -F '\\s*: | @' '/model name|Hardware|Processor|^cpu model|chip type|^cpu type/ { cpu=$2; if ($1 == "Hardware") exit } END { print cpu }' "$cpu_file"
        """).output
        return cpuName.strip
