import types

type Phase* = enum
    opening, endgame

type OurKingOrEnemyKing* = enum
    ourKing, enemyKing

type SinglePhaseEvalParametersTemplate*[ValueType: Value or Float] = object
    pieceValues*: array[pawn..king, ValueType]
    pst*: array[ourKing..enemyKing, array[a1..h8, array[pawn..king, array[a1..h8, ValueType]]]]
    pawnMaskBonus*: array[3*3*3 * 3*3*3 * 3*3*3, ValueType]
    #pawnMaskBonus*: array[262144, ValueType]# 2^18 = 262144
    passedPawnTable*: array[8, ValueType]
    bonusIsolatedPawn*: ValueType
    bonusPawnHasTwoNeighbors*: ValueType
    bonusKnightAttackingPiece*: ValueType
    bonusBothBishops*: ValueType
    bonusRookOnOpenFile*: ValueType
    bonusMobility*: array[knight..queen, array[32, ValueType]]
    bonusTargetingKingArea*: array[bishop..queen, ValueType]
    bonusAttackingKing*: array[bishop..queen, ValueType]
    bonusKingSafety*: array[32, ValueType]

type EvalParametersTemplate*[ValueType] = array[Phase, SinglePhaseEvalParametersTemplate[ValueType]]

type EvalParametersFloat* = EvalParametersTemplate[Float]

type EvalParameters* = EvalParametersTemplate[Value]

func transform*[Out, In](output: var Out, input: In, floatOp: proc(a: var Float, b: Float)) =

    when Out is AtomType:
        static: doAssert In is AtomType, "Transforming types must have the same structure."
        when Out is Float and In is Float:
            floatOp(output, input)
        else:
            output = input.Out
        
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

func transform*[Out, In](output: var Out, input: In) =
    transform(output, input, proc(a: var Float, b: Float) = a = b)

func `*=`*(a: var SinglePhaseEvalParametersTemplate[Float], b: Float) =
    transform(a, a, proc(x: var Float, y: Float) = x *= b)

func convert*(a: auto, T: typedesc): T =
    transform(result, a)

func convert*(a: EvalParameters): EvalParametersFloat =
    a.convert(EvalParametersFloat)

func convert*(a: EvalParametersFloat): EvalParameters =
    a.convert(EvalParameters)

func `+=`*(a: var EvalParametersFloat, b: EvalParametersFloat) =
    transform(a, b, proc(x: var Float, y: Float) = x += y)

func `*=`*(a: var EvalParametersFloat, b: EvalParametersFloat) =
    transform(a, b, proc(x: var Float, y: Float) = x *= y)

func `*=`*(a: var EvalParametersFloat, b: Float) =
    for phase in Phase:
        a[phase] *= b

func setAll*(a: var EvalParametersFloat, b: Float) =
    transform(a, a, proc(x: var Float, y: Float) = x = b)