import std/tables

type
  Value* = float32
  Effort* = float32
  Ply* = int
  ZobristKey* = uint64
  NodeType* = enum
    pvNode
    allNode
    cutNode

const maxPly* = 200

const
  exact* = pvNode
  upperBound* = allNode
  lowerBound* = cutNode

func nextafterf(x, y: cfloat): cfloat {.importc: "nextafterf", header: "<math.h>".}

func nextBelow*(value: Value): Value =
  nextafterf(value, -Inf)

func nextAbove*(value: Value): Value =
  nextafterf(value, Inf)

func checkmateValue*(height: Ply): Value =
  const table = block:
    var
      t: array[0 .. maxPly, Value]
      x: Value = Inf
    for a in t.mitems:
      x = cast[float32](cast[uint32](x) - 1)
      a = x
    t
  table[height.clamp(table.low, table.high)]

const valueCheckmate*: Value = maxPly.checkmateValue

func plysUntilCheckmate*(value: Value): Ply =
  const table = block:
    var t: Table[Value, Ply]
    for height in 0 .. maxPly:
      t[checkmateValue(height)] = height
    t
  table[value.abs]

static:
  doAssert maxPly.checkmateValue >= valueCheckmate
  doAssert 0.checkmateValue < Inf
  doAssert 0.Ply.checkmateValue.plysUntilCheckmate == 0.Ply
  doAssert 1.Ply.checkmateValue.plysUntilCheckmate == 1.Ply
  doAssert 9.Ply.checkmateValue.plysUntilCheckmate == 9.Ply
  doAssert 10.Ply.checkmateValue.plysUntilCheckmate == 10.Ply
  doAssert 100.Ply.checkmateValue.plysUntilCheckmate == 100.Ply
  doAssert 100.Ply.checkmateValue < 99.Ply.checkmateValue
  # doAssert $(9.Ply.checkmateValue) == "mate +5"
  # doAssert $(-(1.Ply.checkmateValue)) == "mate -1"
  # doAssert $(2.Ply.checkmateValue) == "mate +1"
  # doAssert $(-(3.Ply.checkmateValue)) == "mate -2"
  # doAssert $(maxPly.Ply.checkmateValue) == "mate +100"
