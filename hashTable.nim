import
    types,
    move,
    position,
    tables,
    random

type
    HashTableEntry* {.packed.} = object
        zobristKey: uint64
        nodeType*: NodeType
        value*: int16
        depth*: Ply
        bestMove*: Move
    CountedHashTableEntry = object
        entry: HashTableEntry
        lookupCounter: uint32
    HashTable* = object
        nonPvNodes: seq[HashTableEntry]
        pvNodes: Table[uint64, CountedHashTableEntry]

const noEntry = HashTableEntry(zobristKey: 0, nodeType: noNode, depth: 0.Ply, bestMove: noMove)

template isEmpty*(entry: HashTableEntry): bool =
    entry == noEntry

func clear*(ht: var HashTable) =
    ht.pvNodes.clear
    for entry in ht.nonPvNodes.mitems:
        entry = noEntry

func setSize*(ht: var HashTable, sizeInBytes: int) =
    let numEntries = sizeInBytes div sizeof(HashTableEntry)
    ht.nonPvNodes.setLen(max(numEntries, 1))
    ht.clear

func age*(ht: var HashTable)  =
    var deleteQueue: seq[uint64]
    for (key, entry) in ht.pvNodes.mpairs:
        if entry.lookupCounter <= 0:
            deleteQueue.add(key)
        else:
            entry.lookupCounter = 0
    for key in deleteQueue:
        ht.pvNodes.del(key)

func shouldReplace(oldNodeType, newNodeType: NodeType, oldDepth, newDepth: Ply): bool =
    var probability = 1.0 - (0.8/6.0) * clamp(oldDepth - newDepth, 0, 6).float
    if oldNodeType == cutNode and newNodeType == allNode:
        probability -= 0.1
    doAssert probability > 0.09
    {.cast(noSideEffect).}:
        rand(1.0) < probability

func add*(
    ht: var HashTable,
    zobristKey: uint64,
    nodeType: NodeType,
    value: Value,
    depth: Ply,
    bestMove: Move
) =
    let entry = HashTableEntry(
        zobristKey: zobristKey,
        nodeType: nodeType,
        value: value.int16,
        depth: depth,
        bestMove: bestMove
    )
    static: doAssert (valueInfinity <= int16.high.Value and -valueInfinity >= int16.low.Value)

    if nodeType == pvNode:
        if (not ht.pvNodes.hasKey(zobristKey)) or
        ht.pvNodes[zobristKey].entry.depth <= depth:
            ht.pvNodes[zobristKey] = CountedHashTableEntry(entry: entry, lookupCounter: 1)
    else:
        let i = zobristKey mod ht.nonPvNodes.len.uint64
        if ht.nonPvNodes[i].isEmpty or ht.nonPvNodes[i].zobristKey != zobristKey or ht.nonPvNodes[i].depth <= depth:
            if not (ht.nonPvNodes[i].isEmpty or ht.nonPvNodes[i].zobristKey == zobristKey):
                if not shouldReplace(ht.nonPvNodes[i].nodeType, nodeType, ht.nonPvNodes[i].depth, depth):
                    return
            ht.nonPvNodes[i] = entry

func get*(ht: var HashTable, zobristKey: uint64): HashTableEntry =
    
    if ht.pvNodes.hasKey(zobristKey):
        ht.pvNodes[zobristKey].lookupCounter += 1
        return ht.pvNodes[zobristKey].entry

    let i = zobristKey mod ht.nonPvNodes.len.uint64
    if not ht.nonPvNodes[i].isEmpty and zobristKey == ht.nonPvNodes[i].zobristKey:
        return ht.nonPvNodes[i]

    noEntry

func hashFull*(ht: HashTable): int =
    ht.pvNodes.len
            
func getPv*(ht: var HashTable, position: Position): seq[Move] =
    var encounteredZobristKeys: seq[uint64]
    var currentPosition = position
    while true:
        for key in encounteredZobristKeys:
            if key == currentPosition.zobristKey:
                return result
        encounteredZobristKeys.add(currentPosition.zobristKey)
        let entry = ht.get(currentPosition.zobristKey)

        if entry.isEmpty or not currentPosition.isLegal(entry.bestMove):
            return result
        result.add(entry.bestMove)
        currentPosition.doMove(entry.bestMove)


