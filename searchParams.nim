import types

import std/[
    tables,
    macros,
    typetraits,
    strformat,
    json
]

const floatQuantizer = 1_000_000.0

type ParamEntry = object
    address: ptr int
    min: int
    max: int
    step: int

var paramTable: Table[string, ParamEntry]

proc getVarName(name: NimNode): NimNode =
    parseExpr($toStrLit(name) & "Var")

proc getVarString(name: NimNode): NimNode =
    parseExpr("\"" & $toStrLit(name) & "\"")

func getAsInt[T](a: T): int =
    when distinctBase(T) is SomeFloat:
        (a.float * floatQuantizer).int
    else:
        a.int

macro addParam[T](name: untyped, default, min, max, step: T): untyped =
    let
        varName: NimNode = getVarName(name)
        varString: NimNode = getVarString(name)
    quote do:
        var `varName`: int = `default`.getAsInt

        paramTable[`varString`] = ParamEntry(address: addr `varName`, min: `min`.getAsInt, max: `max`.getAsInt, step: `step`.getAsInt)

        func `name`*(): auto =
            type R = typeof(`default`)
            {.cast(noSideEffect).}:
                when distinctBase(R) is SomeFloat:
                    R(R(`varName`).float / floatQuantizer)
                else:
                    R(`varName`)

proc hasSearchOption*(name: string): bool =
    name in paramTable

proc setSearchOption*(name: string, value: int) =
    if name in paramTable:
        let allowedRange = paramTable[name].min..paramTable[name].max
        if value notin allowedRange:
            raise newException(KeyError, "Parameter '" & name & "' doesn't allow values outside " & $allowedRange & " but value is '" & $value & "'" )
        paramTable[name].address[] = value
    else:
        raise newException(KeyError, "Parameter '" & name & "' doesn't exist")

proc printUciSearchParams*() =
    for name, param in paramTable:
        echo "option name ", name, " type spin default ", param.address[], " min ", param.min, " max ", param.max

proc getWeatherFactoryConfig(): string =
    result = "{"
    for name, param in paramTable:
        result &= "\"" & name & "\": {"
        result &= fmt"""
        "value": {param.address[]},
        "min_value": {param.min},
        "max_value": {param.max},
        "step": {param.step}
        """
        result &= "},"
    result &= "}"
    result = result.parseJson.pretty

# type Aaaa = distinct float32

# addParam(myParam, 100.Value, 0.Value, 200.Value, 5.Value)
# addParam(myParam2, 0.5.Aaaa, -0.5.Aaaa, 100.5.Aaaa, 0.1.Aaaa)
# addParam(myParam3, 0.1'f32, -0.2'f32, 100.6'f32, 0.2'f32)

addParam(deltaMargin, default = 100, min = 0, max = 500, step = 20)
addParam(failHighDeltaMargin, default = 50, min = 0, max = 500, step = 10)
addParam(aspirationWindowStartingOffset, default = 10, min = 0, max = 100, step = 2)
addParam(aspirationWindowMultiplier, default = 2.0, min = 1.1, max = 20.0, step = 0.2)
addParam(futilityReductionDiv, default = 100, min = 10, max = 500, step = 20)
addParam(hashResultFutilityMarginMul, default = 300, min = 50, max = 1000, step = 20)
addParam(nullMoveDepthSub, default = 3.Ply, min = 0.Ply, max = 10.Ply, step = 1.Ply)
addParam(nullMoveDepthDiv, default = 4, min = 1, max = 20, step = 1)
addParam(lmrDepthHalfLife, default = 30, min = 5, max = 200, step = 5)
addParam(lmrDepthSub, default = 1.Ply, min = 0.Ply, max = 20.Ply, step = 1.Ply)
addParam(iirMinDepth, default = 6.Ply, min = 0.Ply, max = 20.Ply, step = 1.Ply)
addParam(minMoveCounterLmr, default = 4, min = 0, max = 50, step = 1)
addParam(minMoveCounterFutility, default = 2, min = 0, max = 50, step = 1)

# printUciSearchParams()
when isMainModule:
    echo getWeatherFactoryConfig()

# echo myParam()
# echo myParam2().float32
# echo myParam3()

# paramTable["myParam"].address[] = paramTable["myParam"].max
# paramTable["myParam2"].address[] += paramTable["myParam2"].step
# paramTable["myParam3"].address[] += paramTable["myParam3"].step

# echo myParam()
# echo myParam2().float32
# echo myParam3()
        
