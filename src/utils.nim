import types

import std/[options, strutils, times, os, math, macros]

const megaByteToByte* = 1_048_576

func boardString*(f: proc(square: Square): Option[string] {.noSideEffect.}): string =
  result = " _ _ _ _ _ _ _ _\n"
  for rank in countdown(7, 0):
    for file in 0 .. 7:
      result &= "|"
      let s = f((8 * rank + file).Square)
      if s.isSome:
        result &= s.get()
      else:
        result &= "_"
    result &= "|" & intToStr(rank + 1) & "\n"
  result &= " A B C D E F G H"

func notation*(piece: Piece): string =
  case piece
  of pawn: "p"
  of knight: "n"
  of bishop: "b"
  of rook: "r"
  of queen: "q"
  of king: "k"
  of noPiece: "-"

func notation*(coloredPiece: ColoredPiece): string =
  result = coloredPiece.piece.notation
  if coloredPiece.color == white:
    result = result.toUpperAscii

func `$`*(coloredPiece: ColoredPiece): string =
  const t = [
    white: [
      pawn: "♟", knight: "♞", bishop: "♝", rook: "♜", queen: "♛", king: "♚"
    ],
    black: [
      pawn: "♙", knight: "♘", bishop: "♗", rook: "♖", queen: "♕", king: "♔"
    ],
  ]
  if coloredPiece.piece == noPiece:
    return " "
  return t[coloredPiece.color][coloredPiece.piece]

func toColoredPiece*(s: char): ColoredPiece =
  var piece: pawn..king
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

type Seconds* = distinct float

func `$`*(a: Seconds): string =
  $a.float & " s"

func high*(T: typedesc[Seconds]): Seconds =
  float.high.Seconds
func low*(T: typedesc[Seconds]): Seconds =
  float.low.Seconds

func `==`*(a, b: Seconds): bool {.borrow.}
func `<=`*(a, b: Seconds): bool {.borrow.}
func `<`*(a, b: Seconds): bool {.borrow.}

func `-`*(a, b: Seconds): Seconds {.borrow.}
func `+`*(a, b: Seconds): Seconds {.borrow.}
func `*`*(a: Seconds, b: SomeNumber): Seconds =
  Seconds(a.float * b.float)
func `*`*(a: SomeNumber, b: Seconds): Seconds =
  Seconds(a.float * b.float)
func `/`*(a: Seconds, b: SomeNumber): Seconds =
  Seconds(a.float / b.float)

func `+=`*(a: var Seconds, b: Seconds) =
  a = a + b
func `-=`*(a: var Seconds, b: Seconds) =
  a = a - b
func `*=`*(a: var Seconds, b: SomeNumber) =
  a = a * b
func `/=`*(a: var Seconds, b: SomeNumber) =
  a = a / b

func secondsSince1970*(): Seconds =
  {.cast(noSideEffect).}:
    epochTime().Seconds

macro lazyEval*(assignmentStmt: untyped): untyped =
  expectKind(assignmentStmt, nnkStmtList)
  expectLen(assignmentStmt, 1)

  let assignment = assignmentStmt[0]
  expectKind(assignment, nnkAsgn)

  let
    identifier = assignment[0]
    initExpr = assignment[1]
    storageIdent = genSym(nskVar, $identifier & "Lazy")

  quote:
    var `storageIdent` = none(type(`initExpr`))
    template `identifier`(): auto =
      if `storageIdent`.isNone:
        `storageIdent` = some `initExpr`
      `storageIdent`.get()
