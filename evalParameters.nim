import types
export types

import std/strformat

type Relativity* = enum
    relativeToUs, relativeToEnemy

type SinglePhaseEvalParametersTemplate[ValueType: Value or float32] = object
    kingRelativePst*: array[Relativity, array[a1..h8, array[pawn..noPiece, array[a1..h8, ValueType]]]] # noPiece for passed pawns
    pieceRelativePst*: array[4, array[Relativity, array[pawn..queen, array[a1..h8, array[pawn..queen, array[a1..h8, ValueType]]]]]] # here the pawn in the first dim stand for passed pawns
    pawnStructureBonus*: array[b3..g6, array[3*3*3 * 3*3*3 * 3*3*3, ValueType]]

type EvalParametersTemplate[ValueType] {.requiresInit.} = seq[SinglePhaseEvalParametersTemplate[ValueType]]

type EvalParametersFloat* {.requiresInit.} = EvalParametersTemplate[float32]

type EvalParameters* {.requiresInit.} = EvalParametersTemplate[Value]

func newEvalParametersFloat*(): EvalParametersFloat =
    newSeq[SinglePhaseEvalParametersTemplate[float32]](2)

func newEvalParameters*(): EvalParameters =
    newSeq[SinglePhaseEvalParametersTemplate[Value]](2)

template doForAll[Out, In, F](output: var SinglePhaseEvalParametersTemplate[Out], input: SinglePhaseEvalParametersTemplate[In], f: F) =

    for r in Relativity:
        for s1 in a1..h8:
            for p in pawn..noPiece:
                for s2 in a1..h8:
                    f(output.kingRelativePst[r][s1][p][s2], input.kingRelativePst[r][s1][p][s2])

    for i in 0..3:
        for r in Relativity:
            for p1 in pawn..queen:
                for s1 in a1..h8:
                    for p2 in pawn..queen:
                        for s2 in a1..h8:
                            f(output.pieceRelativePst[i][r][p1][s1][p2][s2], input.pieceRelativePst[i][r][p1][s1][p2][s2])

    for s in b3..g6:
        for i in 0..<3*3*3 * 3*3*3 * 3*3*3:
            f(output.pawnStructureBonus[s][i], input.pawnStructureBonus[s][i])

template doForAll[Out, In, F](output: var EvalParametersTemplate[Out], input: EvalParametersTemplate[In], f: F) =
    for phase in 0..1:
        doForAll(output[phase], input[phase], f)

func `*=`*(a: var SinglePhaseEvalParametersTemplate[float32], b: float32) =
    doForAll(a, a, proc(x: var float32, y: float32){.noSideEffect.} = x *= b)

func convert*(a: EvalParameters): EvalParametersFloat =
    result = newEvalParametersFloat()
    doForAll(result, a, proc(a: var float32, b: Value) {.noSideEffect.} = a = b.float32)

func convert*(a: EvalParametersFloat): EvalParameters =
    result = newEvalParameters()
    doForAll(result, a, proc(a: var Value, b: float32) {.noSideEffect.} = a = b.Value)

func `+=`*(a: var EvalParametersFloat, b: EvalParametersFloat) =
    doForAll(a, b, proc(x: var float32, y: float32) = x += y)

func `*=`*(a: var EvalParametersFloat, b: EvalParametersFloat) =
    doForAll(a, b, proc(x: var float32, y: float32) = x *= y)

func `*=`*(a: var EvalParametersFloat, b: float32) =
    doForAll(a, a, proc(x: var float32, y: float32) = x *= b)

func setAll*(a: var EvalParametersFloat, b: float32) =
    doForAll(a, a, proc(x: var float32, y: float32) = x = b)

func getMask*(a: EvalParametersFloat, margin: float32): EvalParametersFloat =
    result = newEvalParametersFloat()
    doForAll(result, a, proc(x: var float32, y: float32) = x = if y.abs < margin: 0.0 else: 1.0 )

proc toSeq*(a: EvalParameters): seq[int] =
    var tmp = a
    let resultAddr = addr result
    doForAll(tmp, a, proc(x: var Value, y: Value) = resultAddr[].add x.int)

proc toEvalParameters*(s: seq[int]): EvalParameters =
    result = newEvalParameters()
    var i = 0
    let sAddr = addr s
    doForAll(result, result, proc(x: var Value, y: Value) =
        x = sAddr[][i].Value
        i += 1
    )

proc toNimDefaultParamFile*(a: EvalParameters, fileName: string) =
    writeFile(
        fileName,
        &"import evalParameters\n\nconst defaultEvalParameters* = {a.toSeq}.toEvalParameters\n"
    )

