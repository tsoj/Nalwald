import types

import std/[options, bitops, endians, sugar]

export bitops

type Bitboard* = distinct uint64

func `==`*(a, b: Bitboard): bool {.borrow.}
func `and`*(a, b: Bitboard): Bitboard {.borrow.}
func `or`*(a, b: Bitboard): Bitboard {.borrow.}
func `xor`*(a, b: Bitboard): Bitboard {.borrow.}
func `not`*(a: Bitboard): Bitboard {.borrow.}
func `shl`*(a: Bitboard, b: int): Bitboard {.borrow.}
func `shr`*(a: Bitboard, b: int): Bitboard {.borrow.}
func countSetBits*(a: Bitboard): int {.borrow.}

func `&=`*(a: var Bitboard, b: Bitboard) =
  a = a and b
func `|=`*(a: var Bitboard, b: Bitboard) =
  a = a or b

func empty*(bitboard: Bitboard): bool =
  bitboard == 0.Bitboard

func toSquare*(x: Bitboard): Square =
  if x.empty:
    noSquare
  else:
    x.uint64.countTrailingZeroBits.Square

func toBitboard*(square: Square): Bitboard =
  if square == noSquare:
    0.Bitboard
  else:
    Bitboard(1u64 shl square.int8)

func isSet*(b: Bitboard, sq: Square): bool =
  not empty(b and sq.toBitboard)

iterator items*(bitboard: Bitboard): Square =
  var occ = bitboard
  while not occ.empty:
    yield occ.uint64.countTrailingZeroBits.Square
    occ &= (occ.uint64 - 1).Bitboard

func `$`*(b: Bitboard): string =
  boardString(
    proc(square: Square): Option[string] =
      if b.isSet(square):
        return some("●")
      none(string)
  )


func ranks*(square: Square): Bitboard =
  const ranksTable: array[a1 .. h8, Bitboard] = block:
    var ranks: array[a1 .. h8, Bitboard]
    for square in a1 .. h8:
      ranks[square] = 0b11111111u64.Bitboard shl ((square.int8 div 8) * 8)
    ranks
  ranksTable[square]

func files*(square: Square): Bitboard =
  const filesTable: array[a1 .. h8, Bitboard] = block:
    var files: array[a1 .. h8, Bitboard]
    for square in a1 .. h8:
      files[square] =
        0b0000000100000001000000010000000100000001000000010000000100000001u64.Bitboard shl
        (square.int8 mod 8)
    files
  filesTable[square]


func mirrorVertically*(bitboard: Bitboard): Bitboard =
  result = 0.Bitboard
  swapEndian64(addr result, unsafeAddr bitboard)

func mirrorHorizontally*(bitboard: Bitboard): Bitboard =
  result = 0.Bitboard
  for i in 0 .. 3:
    let
      f1 = files(i.Square)
      f2 = files((7 - i).Square)
      shiftAmount = 7 - 2 * i
    result = result or ((bitboard and f1) shl shiftAmount)
    result = result or ((bitboard and f2) shr shiftAmount)


proc attackForSquareAndKey(
    hashKey: uint8,
    startSquare: Square,
    dirs: openArray[int],
    hashKeyFn: (Square, Bitboard) -> uint8,
): Bitboard =
  result = 0.Bitboard
  for dir in dirs:
    var square = startSquare.int
    while true:
      square += dir
      if square notin 0 .. 63 or abs((square mod 8) - ((square - dir) mod 8)) >= 2:
        break
      let sq = square.Square
      result |= sq.toBitboard
      if (hashKeyFn(startSquare, sq.toBitboard) and hashKey) != 0:
        break

proc collect64[T](f: (int -> T)): array[64, T] =
  result = default(array[64, T])
  for i in 0 .. 63:
    result[i] = f(i)

const
  mainDiagonal =
    0b1000000001000000001000000001000000001000000001000000001000000001u64.Bitboard
  diagonals: array[a1 .. h8, Bitboard] =
    collect64 (i) => attackForSquareAndKey(0, i.Square, [-9, 9], (sq, occ) => 0.uint8)
  antiDiagonals: array[a1 .. h8, Bitboard] =
    collect64 (i) => attackForSquareAndKey(0, i.Square, [-7, 7], (sq, occ) => 0.uint8)

#!fmt: off
func hashkeyRank(square: Square, occupancy: Bitboard): uint8 =
  (((occupancy shr ((square.int8 div 8) * 8)) shr 1) and 0b111111.Bitboard).uint8
func hashkeyFile(square: Square, occupancy: Bitboard): uint8 =
  ((((((occupancy shr (square.int8 mod 8)) and files(a1)).uint64 * mainDiagonal.uint64) shr 56) shr 1) and 0b111111).uint8
func hashkeyDiagonal(square: Square, occupancy: Bitboard): uint8 =
  (((((occupancy and diagonals[square]).uint64 * files(a1).uint64) shr 56) shr 1) and 0b111111).uint8
func hashkeyAntiDiagonal(square: Square, occupancy: Bitboard): uint8 =
  (((((occupancy and antiDiagonals[square]).uint64 * files(a1).uint64) shr 56) shr 1) and 0b111111).uint8
#!fmt: on



proc attackTable(
    dirs: array[2, int], hashKeyFn: (Square, Bitboard) -> uint8
): array[a1 .. h8, array[64, Bitboard]] =
  collect64(
    (sq) =>
      collect64((key) => attackForSquareAndKey(key.uint8, sq.Square, dirs, hashKeyFn))
  )

proc kingKnightAttackTable(a1Proto: Bitboard): array[a1 .. h8, Bitboard] =

  collect64(
    proc(sourceSq: int): Bitboard =
      result = 0.Bitboard
      for target in rotateLeftBits(a1Proto.uint64, sourceSq).Bitboard:
        if abs((target.int div 8) - (sourceSq div 8)) +
            abs((target.int mod 8) - (sourceSq mod 8)) <= 3:
          result |= target.toBitboard
  )

const
  rankAttackTable = attackTable([1, -1], hashkeyRank)
  fileAttackTable = attackTable([8, -8], hashkeyFile)
  diagonalAttackTable = attackTable([9, -9], hashkeyDiagonal)
  antiDiagonalAttackTable = attackTable([7, -7], hashkeyAntiDiagonal)
  knightAttackTable = kingKnightAttackTable(0x442800000028440u64.Bitboard)
  kingAttackTable = kingKnightAttackTable(0x8380000000000383u64.Bitboard)

func attackTablePawnQuiet*(color: Color, square: Square): Bitboard =
  const table: array[white .. black, array[a1 .. h8, Bitboard]] = block:
    var attackTablePawnQuiet: array[white .. black, array[a1 .. h8, Bitboard]]
    for square in a2 .. h7:
      attackTablePawnQuiet[white][square] = square.toBitboard shl 8
      attackTablePawnQuiet[black][square] = square.toBitboard shr 8
    attackTablePawnQuiet
  table[color][square]

func attackTablePawnCapture*(color: Color, square: Square): Bitboard =
  const table: array[white .. black, array[a1 .. h8, Bitboard]] = block:
    var attackTablePawnCapture: array[white .. black, array[a1 .. h8, Bitboard]]
    for (color, range) in [(white, a1 .. h7), (black, a2 .. h8)]:
      for square in range:
        let attacks = diagonals[square] or antiDiagonals[square]
        attackTablePawnCapture[color][square] = attacks and ranks(square.up(color))
    attackTablePawnCapture
  table[color][square]

func isPassedMask*(color: Color, square: Square): Bitboard =
  const table: array[white .. black, array[a1 .. h8, Bitboard]] = block:
    var isPassedMask: array[white .. black, array[a1 .. h8, Bitboard]]
    for square in a1 .. h8:
      isPassedMask[white][square] = files(square)
      if not square.isLeftEdge:
        isPassedMask[white][square] = isPassedMask[white][square] or files(square.left)
      if not square.isRightEdge:
        isPassedMask[white][square] = isPassedMask[white][square] or files(square.right)
      isPassedMask[black][square] = isPassedMask[white][square]

      for j in 0 .. 7:
        if j <= (square.int8 div 8):
          isPassedMask[white][square] =
            isPassedMask[white][square] and not ranks((j * 8).Square)
        if j >= (square.int8 div 8):
          isPassedMask[black][square] =
            isPassedMask[black][square] and not ranks((j * 8).Square)
    isPassedMask
  table[color][square]

func mask3x3*(square: Square): Bitboard =
  const table: array[a1 .. h8, Bitboard] = block:
    var mask3x3: array[a1 .. h8, Bitboard]
    for square in a1 .. h8:
      mask3x3[square] = kingAttackTable[square] or square.toBitboard
    mask3x3
  table[square]

func mask5x5*(square: Square): Bitboard =
  const table: array[a1 .. h8, Bitboard] = block:
    var mask5x5: array[a1 .. h8, Bitboard]
    for square in a1 .. h8:
      for a in mask3x3(square):
        mask5x5[square] = mask5x5[square] or mask3x3(a)
    mask5x5
  table[square]

func homeRank*(color: Color): Bitboard =
  case color:
  of white: ranks(a1)
  of black: ranks(a8)

func attackMaskPawnQuiet*(square: Square, color: Color): Bitboard =
  attackTablePawnQuiet(color, square)

func attackMaskPawnCapture*(square: Square, color: Color): Bitboard =
  attackTablePawnCapture(color, square)

func attackMaskKnight*(square: Square, occupancy: Bitboard): Bitboard =
  knightAttackTable[square]

func attackMaskBishop*(square: Square, occupancy: Bitboard): Bitboard =
  antiDiagonalAttackTable[square][hashkeyAntiDiagonal(square, occupancy)] or
    diagonalAttackTable[square][hashkeyDiagonal(square, occupancy)]

func attackMaskRook*(square: Square, occupancy: Bitboard): Bitboard =
  rankAttackTable[square][hashkeyRank(square, occupancy)] or
    fileAttackTable[square][hashkeyFile(square, occupancy)]

func attackMaskQueen*(square: Square, occupancy: Bitboard): Bitboard =
  attackMaskBishop(square, occupancy) or attackMaskRook(square, occupancy)

func attackMaskKing*(square: Square, occupancy: Bitboard): Bitboard =
  kingAttackTable[square]

func attackMask*(piece: knight..king, square: Square, occupancy: Bitboard): Bitboard =
  const attackFunctions = [
    knight: attackMaskKnight,
    bishop: attackMaskBishop,
    rook: attackMaskRook,
    queen: attackMaskQueen,
    king: attackMaskKing,
  ]
  attackFunctions[piece](square, occupancy)
