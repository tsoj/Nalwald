# from system import int8, int32, high
import std/math
#!fmt: off
type Square* = enum
  a1, b1, c1, d1, e1, f1, g1, h1,
  a2, b2, c2, d2, e2, f2, g2, h2,
  a3, b3, c3, d3, e3, f3, g3, h3,
  a4, b4, c4, d4, e4, f4, g4, h4,
  a5, b5, c5, d5, e5, f5, g5, h5,
  a6, b6, c6, d6, e6, f6, g6, h6,
  a7, b7, c7, d7, e7, f7, g7, h7,
  a8, b8, c8, d8, e8, f8, g8, h8,
  noSquare
#!fmt: on

type
  Color* = enum
    white
    black
    noColor

  Piece* = enum
    pawn
    knight
    bishop
    rook
    queen
    king
    noPiece

  ColoredPiece* = object
    piece*: Piece
    color*: Color

  Height* = 0.uint8 .. uint8.high
  Depth* = Height.low.float32 .. Height.high.float32
  Value* = distinct float32

  GamePhase* = 0.0 .. 1.0

  NodeType* = enum
    pvNode
    allNode
    cutNode

  Key* = uint64

func newSquare*(file: int, rank: int): Square =
  Square(rank * 8 + file)

func up*(square: Square): Square =
  (square.int8 + 8).Square

func down*(square: Square): Square =
  (square.int8 - 8).Square

func left*(square: Square): Square =
  (square.int8 - 1).Square

func right*(square: Square): Square =
  (square.int8 + 1).Square

func up*(square: Square, color: Color): Square =
  if color == white: square.up else: square.down

func isLeftEdge*(square: Square): bool =
  square.int8 mod 8 == 0

func isRightEdge*(square: Square): bool =
  square.int8 mod 8 == 7

func isUpperEdge*(square: Square): bool =
  square >= a8

func isLowerEdge*(square: Square): bool =
  square <= h1

func isEdge*(square: Square): bool =
  square.isLeftEdge or square.isRightEdge or square.isUpperEdge or square.isLowerEdge

func opposite*(color: Color): Color =
  (color.uint8 xor 1).Color


func mirrorVertically*(square: Square): Square =
  (square.int8 xor 56).Square

func mirrorHorizontally*(square: Square): Square =
  (square.int8 xor 7).Square


func `^=`*(a: var Key, b: Key) =
  a = a xor b

# Value type functionality
const valueInfinity* = Value(Inf)
const valueDraw* = Value(0.0)

# Borrow standard float operations for Value type
func `+`*(a, b: Value): Value {.borrow.}
func `-`*(a, b: Value): Value {.borrow.}
func `-`*(a: Value): Value {.borrow.}

func `*`*(a: Value, b: SomeNumber): Value =
  Value(a.float * b.float)
func `*`*(a: SomeNumber, b: Value): Value =
  Value(a.float * b.float)
func `/`*(a: Value, b: SomeNumber): Value =
  Value(a.float / b.float)


func `<`*(a, b: Value): bool {.borrow.}
func `<=`*(a, b: Value): bool {.borrow.}
func `==`*(a, b: Value): bool {.borrow.}
func `$`*(a: Value): string {.borrow.}
func abs*(a: Value): Value {.borrow.}

func checkmateValue*(distance: Height = Height.high): Value =
  ## Returns a checkmate value encoded with the specified distance.
  ## Closer checkmates (lower distance) have higher values.
  ## Uses IEEE 754 float32 with exponent 254 (largest non-special) and
  ## fraction directly encoding the inverted distance bits.
  let invertedDistance = Height.high - distance

  # IEEE 754 float32: sign(1) + exponent(8) + fraction(23)
  # Exponent 254 = 0xFE (biased, so actual exponent is 254-127=127)
  # We want positive values, so sign bit = 0
  # Directly store the 8-bit invertedDistance in the fraction bits
  let
    exponentBits = 254'u32 shl 23
    fractionBits = invertedDistance.uint32
    bits = exponentBits or fractionBits

  Value(cast[float32](bits))

func isCheckmate*(value: Value): bool =
  ## Returns true if the value represents a checkmate
  let bits = cast[uint32](value.float32)
  let exponent = (bits shr 23) and 0xFF'u32
  exponent == 254'u32

func checkmateDistance*(value: Value): Height =
  ## Returns the distance to checkmate for a checkmate value
  ## Assumes the value is a checkmate (use isCheckmate to verify)
  let bits = cast[uint32](abs(value).float32)
  let fractionBits = bits and ((1'u32 shl 23) - 1)
  let invertedDistance = fractionBits.uint8
  Height.high - invertedDistance

static:
  assert classify(valueInfinity.float32) == fcInf
  assert valueInfinity > 0.Value

  let
    closestMate = checkmateValue(0)
    farthestMate = checkmateValue(Height.high)

  assert closestMate > farthestMate

  assert classify(closestMate.float32) == fcNormal
  assert classify(farthestMate.float32) == fcNormal

  assert closestMate > 0.Value
  assert farthestMate > 0.Value

  assert closestMate < valueInfinity
  assert farthestMate < valueInfinity
  assert -farthestMate > -valueInfinity

  assert checkmateValue(0) > checkmateValue(1)
  assert checkmateValue(Height.high - 1) > checkmateValue(Height.high)

  assert isCheckmate(checkmateValue(0))
  assert isCheckmate(checkmateValue(Height.high))
  assert not isCheckmate(valueDraw)
  assert not isCheckmate(Value(10000.0))

  assert checkmateDistance(checkmateValue(0)) == 0
  assert checkmateDistance(checkmateValue(5)) == 5
  assert checkmateDistance(checkmateValue(Height.high)) == Height.high

  let
    positiveMate = checkmateValue(3)
    negativeMate = -positiveMate

  assert isCheckmate(positiveMate)
  assert isCheckmate(negativeMate)

  assert checkmateDistance(positiveMate) == checkmateDistance(negativeMate)
  assert checkmateDistance(positiveMate) == 3
  assert checkmateDistance(negativeMate) == 3

  assert positiveMate > negativeMate
  assert positiveMate > valueDraw
  assert negativeMate < valueDraw
