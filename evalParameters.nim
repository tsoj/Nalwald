import types

import std/random

type Relativity* = enum
    relativeToUs, relativeToEnemy

type SinglePhaseEvalParametersTemplate[ValueType: Value or float32] = object
    kingRelativePst*: array[Relativity, array[a1..h8, array[pawn..noPiece, array[a1..h8, ValueType]]]] # noPiece for passed pawns
    pieceRelativePst*: array[4, array[Relativity, array[knight..queen, array[a1..h8, array[pawn..queen, array[a1..h8, ValueType]]]]]]
    pawnStructureBonus*: array[a1..h8, array[3*3*3 * 3*3*3 * 3*3*3, ValueType]]

# TODO write wrapper such that it looks like an array[Phase, ...] from the outside
type EvalParametersTemplate[ValueType] {.requiresInit.} = seq[SinglePhaseEvalParametersTemplate[ValueType]]

type EvalParametersFloat* {.requiresInit.} = EvalParametersTemplate[float32]

type EvalParameters* {.requiresInit.} = EvalParametersTemplate[Value]

func newEvalParametersFloat*(): EvalParametersFloat =
    newSeq[SinglePhaseEvalParametersTemplate[float32]](2)

func newEvalParameters*(): EvalParameters =
    newSeq[SinglePhaseEvalParametersTemplate[Value]](2)


func transform[Out, In](output: var Out, input: In, floatOp: proc(a: var float32, b: float32) {.noSideEffect.}) =

    when Out is AtomType:
        static: doAssert In is AtomType, "Transforming types must have the same structure."
        var tmp = output.float32
        floatOp(tmp, input.float32)
        output = tmp.Out
        
    elif Out is (tuple or object):
        static: doAssert In is (tuple or object), "Transforming types must have the same structure."
        for inName, inValue in fieldPairs(input):
            var found = false
            for outName, outValue in fieldPairs(output):
                when inName == outName:
                    transform(outValue, inValue, floatOp)
                    found = true
                    break
            assert found, "Transforming types must have the same structure."

    elif Out is array:
        static: doAssert In is array, "Transforming types must have the same structure."
        static: doAssert input.len == output.len, "Transforming types must have the same structure."
        for i in 0..<input.len:
            var outputIndex = (typeof(output.low))((output.low.int + i))
            var inputIndex = (typeof(input.low))((input.low.int + i))
            transform(output[outputIndex], input[inputIndex], floatOp)

    elif Out is seq:
        static: doAssert In is seq, "Transforming types must have the same structure."
        output.setLen input.len
        for i in 0..<input.len:
            transform(output[i], input[i], floatOp)
    
    else:
        static: doAssert false, "Type is not not implemented for transforming"

func transform[Out, In](output: var Out, input: In) =
    transform(output, input, proc(a: var float32, b: float32) = a = b)

func `*=`*(a: var SinglePhaseEvalParametersTemplate[float32], b: float32) =
    transform(a, a, proc(x: var float32, y: float32) = x *= b)

func convert*(a: auto, T: typedesc): T =
    when T is EvalParametersFloat:
        result = newEvalParametersFloat()
    elif T is EvalParameters:
        result = newEvalParameters()
    transform(result, a)


func convert*(a: EvalParameters): EvalParametersFloat =
    a.convert(EvalParametersFloat)

func convert*(a: EvalParametersFloat): EvalParameters =
    a.convert(EvalParameters)

func `+=`*(a: var EvalParametersFloat, b: EvalParametersFloat) =
    transform(a, b, proc(x: var float32, y: float32) = x += y)

func `*=`*(a: var EvalParametersFloat, b: EvalParametersFloat) =
    transform(a, b, proc(x: var float32, y: float32) = x *= y)

func `*=`*(a: var EvalParametersFloat, b: float32) =
    transform(a, a, proc(x: var float32, y: float32) = x *= b)

func setAll*(a: var EvalParametersFloat, b: float32) =
    transform(a, a, proc(x: var float32, y: float32) = x = b)

proc addRand*(a: var EvalParametersFloat, amplitude: float32) =
    func floatOp(x: var float32, y: float32) =
        {.cast(noSideEffect).}:
            x += rand(-amplitude..amplitude)
    transform(a, a, floatOp)