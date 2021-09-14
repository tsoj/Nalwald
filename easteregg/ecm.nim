import
    macros,
    macrocache,
    strutils,
    typetraits,
    tables

const nextTypeId = CacheCounter("nextTypeId")

type TypeId = int

# number of components is limited, as the bit mask is only of size 64 bit
const maxNumComponentTypes = 63
const entityBit = 0b1

func typeId*(T:typedesc): TypeId =
    const id = nextTypeId.value
    static:
        doAssert id < maxNumComponentTypes, "Maximum number of different component types is " & $maxNumComponentTypes
        inc nextTypeId
    id

func bitTypeId(id: TypeId): uint64 =
    (0b10'u64 shl id)

func bitTypeId(T: typedesc): uint64 =
    let bitID {.global.} = bitTypeId(typeId(T))
    {.cast(noSideEffect).}:
        bitID

func bitTypeIdUnion(Ts: tuple): uint64 =
    {.cast(noSideEffect).}:
        var bitId {.global.}: uint64
        once:
            bitId = 0
            for T in Ts.fields:
                bitId = bitId or bitTypeId(typeof T)
        assert (bitId and entityBit) == 0
        bitId

type ComponentVectors = object
    vec: seq[ref seq[int8]]
    destroyFunctions: Table[int, proc(vec: ref seq[int8])]

proc `=destroy`(x: var ComponentVectors) =
    for id, destroyFunction in x.destroyFunctions.mpairs:
        destroyFunction(x.vec[id])
    `=destroy`(x.vec)
    `=destroy`(x.destroyFunctions)

func get(componentVectors: var ComponentVectors, T: typedesc): var seq[T] =
    static: doAssert (ref seq[int8]).default == nil
    let id = typeId(T)

    if componentVectors.vec.len <= id:
        componentVectors.vec.setLen(id + 1)

    if componentVectors.vec[id] == nil:
        doAssert not (id in componentVectors.destroyFunctions)
        componentVectors.destroyFunctions[id] = proc(vec: ref seq[int8]) =
            doAssert vec != nil
            for e in cast[ref seq[T]](vec)[].mitems:
                `=destroy`(e)

        static: doAssert typeof(new seq[T]) is ref seq[T]
        componentVectors.vec[id] = cast[ref seq[int8]](new seq[T])

    assert componentVectors.vec[id] != nil
    cast[ref seq[T]](componentVectors.vec[id])[]

func get(componentVectors: ComponentVectors, T: typedesc): lent seq[T] =
    let id = typeId(T)
    doAssert componentVectors.vec.len > id and componentVectors.vec[id] != nil
    cast[ref seq[T]](componentVectors.vec[id])[]

type Entity* = distinct int
func `<`*(x, y: Entity): bool {.borrow.}
func `<=`*(x, y: Entity): bool {.borrow.}
func `==`*(x, y: Entity): bool {.borrow.}
func `$`*(x: Entity): string {.borrow.}

type EntityComponentManager* = object
    componentVectors: ComponentVectors
    hasMask: seq[uint64]
    componentTypeToEntity: array[maxNumComponentTypes, seq[Entity]]
    unusedEntities: seq[Entity]

func has*(ecm: EntityComponentManager, entity: Entity): bool =
    if entity.int < ecm.hasMask.len:
        return (ecm.hasMask[entity.int] and entityBit) != 0
    false

func hasImpl*(ecm: EntityComponentManager, entity: Entity, ComponentTypes: tuple): bool =
    if ecm.has(entity):
        let bitId = bitTypeIdUnion(ComponentTypes)
        return (ecm.hasMask[entity.int] and bitId) == bitId
    false

template has*(ecm: EntityComponentManager, entity: Entity, ComponentTypes: untyped): bool =
    var test: ComponentTypes
    when test is tuple:
        var t: ComponentTypes
    else:
        var t: (ComponentTypes,)
    ecm.hasImpl(entity, t)

func addEntity*(ecm: var EntityComponentManager): Entity =
    if ecm.unusedEntities.len > 0:
        result = ecm.unusedEntities.pop()
        assert ecm.hasMask[result.int] == 0
        ecm.hasMask[result.int] = entityBit
    else:
        result = ecm.hasMask.len.Entity
        ecm.hasMask.add(entityBit)
    assert result.int < ecm.hasMask.len
    assert ecm.hasMask[result.int] == entityBit

func remove(typeToEntity: var seq[Entity], entity: Entity) =
    let index = typeToEntity.find(entity)
    assert index != -1
    typeToEntity.del(index)

func remove*(ecm: var EntityComponentManager, entity: Entity) =
    if not ecm.has(entity):
        raise newException(KeyError, "Entity cannot be removed: Entity " & $entity & " does not exist.")

    for id in 0..<maxNumComponentTypes:
        if (ecm.hasMask[entity.int] and bitTypeId(id)) != 0:
            ecm.componentTypeToEntity[id].remove(entity)

    ecm.hasMask[entity.int] = 0
    ecm.unusedEntities.add(entity)

func add*[T](ecm: var EntityComponentManager, entity: Entity, component: T) =
    if not ecm.has(entity):
        raise newException(
            KeyError,
            "Component cannot be added to entity: Entity " & $entity & " does not exist."
        )
    if ecm.has(entity, T):
        raise newException(
            KeyError,
            "Component cannot be added to entity: Entity " & $entity & " already has component " & $T & "."
        )
    
    template componentVector: auto = ecm.componentVectors.get(T)
    if componentVector.len <= entity.int:
        componentVector.setLen(entity.int + 1)
    componentVector[entity.int] = component
    ecm.hasMask[entity.int] = ecm.hasMask[entity.int] or bitTypeId(T)
    ecm.componentTypeToEntity[typeId(T)].add entity

func remove*(ecm: var EntityComponentManager, entity: Entity, T: typedesc) =
    if not ecm.has(entity):
        raise newException(
            KeyError,
            "Component cannot be removed from entity: Entity " & $entity & " does not exist."
        )
    if not ecm.has(entity, T):
        raise newException(
            KeyError,
            "Component cannot be remove from entity: Entity " & $entity & " does not have component " & $T & "."
        )
    
    ecm.hasMask[entity.int] = ecm.hasMask[entity.int] and not bitTypeId(T)
    ecm.componentTypeToEntity[typeId(T)].remove(entity)

template getTemplate(ecm: EntityComponentManager or var EntityComponentManager, entity: Entity, T: typedesc): auto =
    if not ecm.has(entity):
        raise newException(
            KeyError,
            "Component cannot be accessed: Entity " & $entity & " does not exist."
        )
    if not ecm.has(entity, T):
        raise newException(
            KeyError,
            "Component cannot be accessed: Entity " & $entity & " does not have component " & $T & "."
        )
    
    assert ecm.componentVectors.get(T).len > entity.int
    ecm.componentVectors.get(T)[entity.int]

func get*[T](ecm: var EntityComponentManager, entity: Entity, desc: typedesc[T]): var T =
    ecm.getTemplate(entity, T)
func get*[T](ecm: EntityComponentManager, entity: Entity, desc: typedesc[T]): lent T =
    ecm.getTemplate(entity, T)

template `[]`*(ecm: EntityComponentManager or var EntityComponentManager, entity: Entity, T: typedesc): auto =
    ecm.get(entity, T)
template `[]=`*[T](ecm: var EntityComponentManager, entity: Entity, t: T) =
    ecm.get(entity, typedesc[T]) = t

func getRarestComponent(ecm: EntityComponentManager, ComponentTypes: tuple): TypeId =
    var min = int.high
    for T in ComponentTypes.fields:
        let id = typeId(typeof T)
        if min > ecm.componentTypeToEntity[id].len:
            min = ecm.componentTypeToEntity[id].len
            result = id

iterator iterImpl*(ecm: EntityComponentManager, ComponentTypes: tuple): Entity =
    let rarestComponent = ecm.getRarestComponent(ComponentTypes)
    for entity in ecm.componentTypeToEntity[rarestComponent]:
        if ecm.hasImpl(entity, ComponentTypes):
            yield entity

template iter*(ecm: EntityComponentManager, ComponentTypes: varargs[untyped]): auto =
    ecm.iterImpl((new (ComponentTypes,))[])

iterator iterAll*(ecm: EntityComponentManager): Entity =
    for i, hasMask in ecm.hasMask.pairs:
        if ecm.has(i.Entity):
            yield i.Entity

macro forEach*(args: varargs[untyped]): untyped =
    args.expectMinLen 3
    args[0].expectKind nnkIdent
    args[^1].expectKind nnkStmtList

    let ecmVarIdent = args[0]
    var paramsIdentDefs = @[newEmptyNode()]
    var typeIdents: seq[NimNode]
    for n in args[1..^2]:
        n.expectKind nnkExprColonExpr
        paramsIdentDefs.add newIdentDefs(n[0], n[1])

        if n[1].kind == nnkVarTy:
            typeIdents.add n[1][0]
        else:
            typeIdents.add n[1]

    let bodyProcIdent = ident("bodyProc")        
    let forLoopEntity = ident("entity")

    var bodyProcCall = newCall(bodyProcIdent)
    for t in typeIdents:
        bodyProcCall.add newCall(ident("get"), ecmVarIdent, forLoopEntity, t)
    
    newStmtList(
        newBlockStmt(
            newStmtList(
                newProc(
                    name = bodyProcIdent,
                    body = args[^1],
                    params = paramsIdentDefs
                ),
                newNimNode(nnkForStmt).add([
                    forLoopEntity,
                    newCall(ident("iter"), ecmVarIdent).add typeIdents,
                    newStmtList(bodyProcCall)
                ])
            )
        )
    )
