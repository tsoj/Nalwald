import types
export types

import std/[os, random, math]

type Relativity* = enum
  relativeToUs
  relativeToEnemy

#!fmt: off
type SinglePhaseEvalParameters = object
  # here the pawn in the first dim stand for passed pawns
  pieceRelativePst*: array[2, array[4, array[Relativity, array[pawn..king, array[a1..h8, array[pawn..king, array[a1..h8, float32]]]]]]]
  pawnStructureBonus*: array[b3..g6, array[3*3*3 * 3*3*3 * 3*3*3, float32]]
  pieceComboBonus*: array[3*3*3*3*3 * 3*3*3*3*3, float32]
#!fmt: on

type EvalParameters* {.requiresInit.} = seq[SinglePhaseEvalParameters]

func newEvalParameters*(): EvalParameters =
  newSeq[SinglePhaseEvalParameters](2)

func doForAll[T](
    output: var T,
    input: T,
    operation: proc(a: var float32, b: float32) {.noSideEffect.},
) =
  when T is AtomType:
    var tmp = output.float32
    operation(tmp, input.float32)
    output = tmp.T
  elif T is object:
    for name, inValue, outValue in fieldPairs(input, output):
      doForAll(outValue, inValue, operation)
  elif T is array:
    for index in T.low .. T.high:
      doForAll(output[index], input[index], operation)
  elif T is seq:
    for index in 0 ..< output.len:
      doForAll(output[index], input[index], operation)
  else:
    static:
      doAssert false, "Type is not not implemented for doForAll: " & $typeof(T)

func `+=`*(a: var EvalParameters, b: EvalParameters) =
  proc op(x: var float32, y: float32) =
    x += y

  doForAll(a, b, op)

func `*=`*(a: var EvalParameters, b: EvalParameters) =
  proc op(x: var float32, y: float32) =
    x *= y

  doForAll(a, b, op)

func `*=`*(a: var EvalParameters, b: float32) =
  proc op(x: var float32, y: float32) =
    x *= b

  doForAll(a, a, op)

func setAll*(a: var EvalParameters, b: float32) =
  proc op(x: var float32, y: float32) =
    x = b

  doForAll(a, a, op)

proc setRandom*(a: var EvalParameters, b: Slice[float64]) =
  proc op(x: var float32, y: float32) =
    {.cast(noSideEffect).}:
      x = rand(b).float32

  doForAll(a, a, op)

const
  charWidth = 8
  quantizeScalar: float32 = 10.0

proc toString*(params: EvalParameters): string =
  var
    s: string = ""
    params = params

  proc op(x: var float32, y: float32) =
    let value = x * quantizeScalar
    doAssert value in int16.low.float32 .. int16.high.float32
    for i in 0 ..< sizeof(int16):
      let
        shift = charWidth * i
        bits = cast[char]((value.int16 shr shift) and 0b1111_1111)
      s.add bits

  doForAll(params, params, op)
  s

proc toEvalParameters*(s: string): EvalParameters =
  var
    params = newEvalParameters()
    n = 0

  proc op(x: var float32, y: float32) =
    var bits: int16 = 0
    for i in 0 ..< sizeof(int16):
      let shift = charWidth * i
      bits = bits or (cast[int16](s[n]) shl shift)
      n += 1
    x = bits.float32 / quantizeScalar

  doForAll(params, params, op)

  params

const defaultEvalParametersString = block:
  var s = ""

  const fileName = "res/params/default.bin"
  if fileExists fileName:
    # For some reason staticRead starts relative paths at the source file location
    s = staticRead("../" & fileName)
  else:
    echo "WARNING! Couldn't find default eval params at ", fileName
  s

let defaultEvalParametersData* = block:
  var ep = newEvalParameters()

  if defaultEvalParametersString.len > 0:
    if defaultEvalParametersString.len == ep.toString.len:
      ep = defaultEvalParametersString.toEvalParameters()
    else:
      echo "WARNING! Incompatible params format"
  else:
    echo "WARNING! Empty eval params string"
  ep

template defaultEvalParameters*(): EvalParameters =
  {.cast(noSideEffect).}:
    defaultEvalParametersData
