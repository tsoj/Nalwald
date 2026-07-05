import std/[os, math]

import zstd/[compress, decompress]

import nimchess

import types

type EvalParameters = object
  psqt*: array[pawn .. king, array[a1 .. h8, Value]]

func newEvalParameters*(): EvalParameters =
  discard
  
const numFloats = sizeof(EvalParameters) div sizeof(Value)

static:
  doAssert sizeof(EvalParameters) == numFloats * sizeof(Value)

template floats(phase: EvalParameters): untyped =
  cast[ptr array[numFloats, float32]](addr phase)[]

iterator iter(
    a: var EvalParameters, b: EvalParameters | bool = false
): (var float32, float32) =
  for j in 0 ..< numFloats:
    when b is bool:
      yield (a.floats[j], 0'f32)
    else:
      yield (a.floats[j], b.floats[j])

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
  var n = 0
  for (x, _) in result.iter:
    let bits = int16(s[n].uint8) or (int16(s[n + 1].uint8) shl 8)
    n += 2
    x = bits.float32 / quantizeScalar

func asString(bytes: seq[byte]): string =
  result = newString(bytes.len)
  if bytes.len > 0:
    copyMem(addr result[0], unsafeAddr bytes[0], bytes.len)

proc toString*(params: EvalParameters): string =
  let raw = params.toStringUncompressed
  compress(raw.toOpenArrayByte(0, raw.high), level = 19).asString

proc toEvalParameters*(s: string): EvalParameters =
  if s.len == 0:
    raise newException(ValueError, "Empty eval params string")
  let uncompressed = decompress(s.toOpenArrayByte(0, s.high)).asString
  if uncompressed.len != newEvalParameters().toStringUncompressed.len:
    raise newException(ValueError, "Incompatible params format")
  uncompressed.toEvalParametersFromUncompressed()

const defaultEvalParametersString = block:
  var s = ""

  const fileName = "res/params/default.zst"
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
  except ValueError:
    echo "WARNING! Default eval params not used: ", getCurrentExceptionMsg()
  ep

template defaultEvalParameters*(): EvalParameters =
  {.cast(noSideEffect).}:
    defaultEvalParametersData
