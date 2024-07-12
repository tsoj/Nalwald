import types
export types

import std/[os, random, math]

type Relativity* = enum
  relativeToUs
  relativeToEnemy

#!fmt: off
type SinglePhaseEvalParametersTemplate[ValueType: Value or float32] = object
  pst*: array[pawn..noPiece, array[a1..h8, ValueType]]
#!fmt: on

type EvalParametersTemplate*[ValueType] {.requiresInit.} =
  seq[SinglePhaseEvalParametersTemplate[ValueType]]

type EvalParametersFloat* {.requiresInit.} = EvalParametersTemplate[float32]

type EvalParameters* {.requiresInit.} = EvalParametersTemplate[Value]

func newEvalParameters*(
    ValueType: typedesc[Value or float32]
): EvalParametersTemplate[ValueType] =
  newSeq[SinglePhaseEvalParametersTemplate[ValueType]](2)

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

func `+=`*(a: var EvalParametersFloat, b: EvalParametersFloat) =
  proc op(x: var float32, y: float32) =
    x += y

  doForAll(a, b, op)

func `*=`*(a: var EvalParametersFloat, b: EvalParametersFloat) =
  proc op(x: var float32, y: float32) =
    x *= y

  doForAll(a, b, op)

func `*=`*(a: var EvalParametersFloat, b: float32) =
  proc op(x: var float32, y: float32) =
    x *= b

  doForAll(a, a, op)

func setAll*(a: var EvalParametersFloat, b: float32) =
  proc op(x: var float32, y: float32) =
    x = b

  doForAll(a, a, op)

proc setRandom*(a: var EvalParametersFloat, b: Slice[float64]) =
  proc op(x: var float32, y: float32) =
    {.cast(noSideEffect).}:
      x = rand(b).float32

  doForAll(a, a, op)

const charWidth = 8

proc toString*(params: EvalParametersTemplate): string =
  var
    s: string
    params = params

  proc op(x: var float32, y: float32) =
    doAssert x in int16.low.float32 .. int16.high.float32
    for i in 0 ..< sizeof(int16):
      let
        shift = charWidth * i
        bits = cast[char]((x.int16 shr shift) and 0b1111_1111)
      s.add bits

  doForAll(params, params, op)
  s

proc toEvalParameters*(
    s: string, ValueType: typedesc[Value or float32]
): EvalParametersTemplate[ValueType] =
  var
    params = newEvalParameters(ValueType)
    n = 0

  proc op(x: var float32, y: float32) =
    var bits: int16 = 0
    for i in 0 ..< sizeof(int16):
      let shift = charWidth * i
      bits = bits or (cast[int16](s[n]) shl shift)
      n += 1
    x = bits.float32

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
  var ep = newEvalParameters(Value)

  if defaultEvalParametersString.len > 0:
    if defaultEvalParametersString.len == ep.toString.len:
      ep = defaultEvalParametersString.toEvalParameters(Value)
    else:
      echo "WARNING! Incompatible params format"
  else:
    echo "WARNING! Empty eval params string"
  ep

template defaultEvalParameters*(): EvalParameters =
  {.cast(noSideEffect).}:
    defaultEvalParametersData
