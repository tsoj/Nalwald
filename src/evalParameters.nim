import types
export types

import zippy

import std/[os, random, math]

type Relativity* = enum
  relativeToUs
  relativeToEnemy

#!fmt: off
type SinglePhaseEvalParameters = object
  # here the pawn in the first dim stand for passed pawns
  pieceRelativePst*: array[2, array[4, array[Relativity, array[pawn..king, array[a1..h8, array[knight..king, array[a1..h8, float32]]]]]]]
  pawnRelativePst*: array[2, array[4, array[knight..king, array[a1..h8, array[3, array[a2..h7, array[a2..h7, float32]]]]]]]
  pawnStructureBonus*: array[b3..g6, array[3*3*3 * 3*3*3 * 3*3*3, float32]]
  pieceComboBonus*: array[3*3*3*3*3 * 3*3*3*3*3, float32]
#!fmt: on

type EvalParameters* {.requiresInit.} = seq[SinglePhaseEvalParameters]

const singlePhaseNumFloats = sizeof(SinglePhaseEvalParameters) div sizeof(float32)
static:
  # SinglePhaseEvalParameters must be a flat blob of float32 for the
  # cast in `floats` to be valid
  doAssert sizeof(SinglePhaseEvalParameters) == singlePhaseNumFloats * sizeof(float32)

template floats(phase: SinglePhaseEvalParameters): untyped =
  cast[ptr array[singlePhaseNumFloats, float32]](addr phase)[]

iterator iter(
    a: var EvalParameters, b: EvalParameters | bool = false
): (var float32, float32) =
  when b isnot bool:
    doAssert a.len == b.len
  for i in 0 ..< a.len:
    for j in 0 ..< singlePhaseNumFloats:
      when b is bool:
        yield (a[i].floats[j], 0'f32)
      else:
        yield (a[i].floats[j], b[i].floats[j])

func newEvalParameters*(): EvalParameters =
  newSeq[SinglePhaseEvalParameters](2)

func `+=`*(a: var EvalParameters, b: EvalParameters) =
  for (x, y) in iter(a, b):
    x += y

func `*=`*(a: var EvalParameters, b: EvalParameters) =
  for (x, y) in iter(a, b):
    x *= y

func `*=`*(a: var EvalParameters, b: float32) =
  for (x, _) in a.iter:
    x *= b

func setAll*(a: var EvalParameters, b: float32) =
  for (x, _) in a.iter:
    x = b

proc setRandom*(a: var EvalParameters, b: Slice[float64]) =
  for (x, _) in a.iter:
    x = rand(b).float32

const quantizeScalar: float32 = 10.0

proc toStringUncompressed(params: EvalParameters): string =
  var params = params
  for (x, _) in params.iter:
    let value = round(x * quantizeScalar)
    doAssert value in int16.low.float32 .. int16.high.float32
    let quantized = value.int16
    result.add cast[char](quantized and 0xff)
    result.add cast[char]((quantized shr 8) and 0xff)

proc toEvalParametersFromUncompressed(s: string): EvalParameters =
  result = newEvalParameters()
  doAssert s.len == 2 * result.len * singlePhaseNumFloats
  var n = 0
  for (x, _) in result.iter:
    let bits = int16(s[n].uint8) or (int16(s[n + 1].uint8) shl 8)
    n += 2
    x = bits.float32 / quantizeScalar

proc toString*(params: EvalParameters): string =
  params.toStringUncompressed.compress

proc toEvalParameters*(s: string): EvalParameters =
  let uncompressed = s.uncompress
  if uncompressed.len == 0:
    raise newException(ValueError, "Empty eval params string")
  if uncompressed.len != newEvalParameters().toStringUncompressed.len:
    raise newException(ValueError, "Incompatible params format")
  uncompressed.toEvalParametersFromUncompressed()

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
  try:
    ep = defaultEvalParametersString.toEvalParameters()
  except ValueError, ZippyError:
    echo "WARNING! Default eval params not used: ", getCurrentExceptionMsg()
  ep

template defaultEvalParameters*(): EvalParameters =
  {.cast(noSideEffect).}:
    defaultEvalParametersData
