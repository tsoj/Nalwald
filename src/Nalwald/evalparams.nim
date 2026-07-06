import std/[os, math]

import zstd/[compress, decompress]

import nimchess

import types

type SinglePhaseEvalParameters = object
  psqt*: array[white .. black, array[pawn .. king, array[a1 .. h8, Value]]]

type EvalParameters* {.requiresInit.} = seq[SinglePhaseEvalParameters]

func newEvalParameters*(): EvalParameters =
  newSeq[SinglePhaseEvalParameters](2)

const numFloats = sizeof(SinglePhaseEvalParameters) div sizeof(Value)

static:
  doAssert sizeof(SinglePhaseEvalParameters) == numFloats * sizeof(Value)

template floats(phase: SinglePhaseEvalParameters): untyped =
  cast[ptr array[numFloats, float32]](addr phase)[]

iterator iter(
    a: var EvalParameters, b: EvalParameters | bool = false
): (var float32, float32) =
  for i in a.low .. a.high:
    for j in 0 ..< numFloats:
      when b is bool:
        yield (a[i].floats[j], 0'f32)
      else:
        yield (a[i].floats[j], b[i].floats[j])

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

proc toStringUncompressed(params: EvalParameters): string =
  var params = params
  for (x, _) in params.iter:
    let bits = cast[uint32](x)
    for i in 0 ..< 4:
      result.add cast[char]((bits shr (8 * i)) and 0xff)

proc toEvalParametersFromUncompressed(s: string): EvalParameters =
  result = newEvalParameters()
  var n = 0
  for (x, _) in result.iter:
    var bits: uint32 = 0
    for i in 0 ..< 4:
      bits = bits or (uint32(s[n + i].uint8) shl (8 * i))
    n += 4
    x = cast[float32](bits)

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

const evalFile {.strdefine.} = "res/params/default.zst"

const defaultEvalParametersString = block:
  var s = ""

  if fileExists evalFile:
    when evalFile.isAbsolute:
      s = staticRead(evalFile)
    else:
      # For some reason staticRead starts relative paths at the source file location
      s = staticRead("../../" & evalFile)
  else:
    echo "WARNING! Couldn't find default eval params at ", evalFile
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
