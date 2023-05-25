import types

import std/random

type OurKingOrEnemyKing* = enum
    ourKing, enemyKing

type SinglePhaseEvalParametersTemplate*[ValueType: Value or float32] = object
    pieceValues*: array[pawn..king, ValueType]
    pst*: array[ourKing..enemyKing, array[a1..h8, array[pawn..noPiece, array[a1..h8, ValueType]]]] # noPiece for passed pawns
    pawnMaskBonus*: array[4, array[3*3*3 * 3*3*3 * 3*3*3, ValueType]]
    bonusPawnCanMove*: ValueType
    bonusPassedPawnCanMove*: array[8, ValueType]
    bonusKnightAttackingPiece*: ValueType
    bonusPieceForkedMajorPieces*: ValueType
    bonusBothBishops*: ValueType
    bonusRookOnOpenFile*: ValueType
    bonusPieceAttackedByPawn*: ValueType
    bonusMobility*: array[knight..queen, array[32, ValueType]]
    bonusAttackingPiece*: array[knight..queen, array[pawn..king, ValueType]]
    bonusTargetingKingArea*: array[bishop..queen, ValueType]
    bonusKingSafety*: array[32, ValueType]
    bonusAttackersNearKing*: array[5*5, ValueType]

type EvalParametersTemplate*[ValueType] = array[Phase, SinglePhaseEvalParametersTemplate[ValueType]]

type EvalParametersFloat* = EvalParametersTemplate[float32]

type EvalParameters* = EvalParametersTemplate[Value]

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
    
    else:
        static: doAssert false, "Type is not not implemented for transforming"

func transform[Out, In](output: var Out, input: In) =
    transform(output, input, proc(a: var float32, b: float32) = a = b)

func `*=`*(a: var SinglePhaseEvalParametersTemplate[float32], b: float32) =
    transform(a, a, proc(x: var float32, y: float32) = x *= b)

func convert*(a: auto, T: typedesc): T =
    transform(result, a)

func convertRef*(a: auto, T: typedesc): ref T =
    result = new T
    transform(result[], a)

func convert*(a: EvalParameters): ref EvalParametersFloat =
    a.convertRef(EvalParametersFloat)

func convert*(a: EvalParametersFloat): ref EvalParameters =
    a.convertRef(EvalParameters)

func `+=`*(a: var EvalParametersFloat, b: EvalParametersFloat) =
    transform(a, b, proc(x: var float32, y: float32) = x += y)

func `*=`*(a: var EvalParametersFloat, b: EvalParametersFloat) =
    transform(a, b, proc(x: var float32, y: float32) = x *= y)

func `*=`*(a: var EvalParametersFloat, b: float32) =
    for phase in Phase:
        a[phase] *= b

func setAll*(a: var EvalParametersFloat, b: float32) =
    transform(a, a, proc(x: var float32, y: float32) = x = b)

proc addRand*(a: var EvalParametersFloat, amplitude: float32) =
    func floatOp(x: var float32, y: float32) =
        {.cast(noSideEffect).}:
            x += rand(-amplitude..amplitude)
    transform(a, a, floatOp)