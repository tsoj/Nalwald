import
    types,
    move,
    position,
    tables,
    random,
    locks

type
    HashTableEntry* {.packed.} = object
        upperZobristKeyAndValue: uint64
        nodeType*: NodeType
        depth*: Ply
        bestMove*: Move
    CountedHashTableEntry = object
        entry: HashTableEntry
        lookupCounter: uint32
    HashTable* {.requiresInit.} = object
        nonPvNodes: seq[HashTableEntry]
        hashFullCounter: int
        pvNodes: Table[uint64, CountedHashTableEntry]
        pvTableMutex: Lock
        randState: Rand

const
    noEntry = HashTableEntry(upperZobristKeyAndValue: 0, depth: 0.Ply, bestMove: noMove)
    sixteenBitMask = 0b1111_1111_1111_1111'u64

func value*(entry: HashTableEntry): Value =
    (cast[int16](entry.upperZobristKeyAndValue and sixteenBitMask)).Value
func sameUpperZobristKey(a: uint64, b: uint64): bool =
    (a and not sixteenBitMask) == (b and not sixteenBitMask)

func newHashTable*(): HashTable =
    result = HashTable(
        nonPvNodes: newSeq[HashTableEntry](0),
        hashFullCounter: 0,
        pvNodes: Table[uint64, CountedHashTableEntry](),
        pvTableMutex: Lock(),
        randState: initRand(0)
    )
    initLock result.pvTableMutex

template isEmpty*(entry: HashTableEntry): bool =
    entry == noEntry

func clear*(ht: var HashTable) =
    ht.randState = initRand(0)
    ht.pvNodes.clear
    ht.hashFullCounter = 0
    for entry in ht.nonPvNodes.mitems:
        entry = noEntry

func setSize*(ht: var HashTable, sizeInBytes: int) =
    let numEntries = sizeInBytes div sizeof(HashTableEntry)
    ht.nonPvNodes.setLen(max(numEntries, 1))
    ht.clear

func age*(ht: var HashTable) =
    var deleteQueue: seq[uint64]
    for (key, entry) in ht.pvNodes.mpairs:
        if entry.lookupCounter <= 0:
            deleteQueue.add(key)
        else:
            entry.lookupCounter = 0
    for key in deleteQueue:
        ht.pvNodes.del(key)

func shouldReplace(ht: var HashTable, newEntry, oldEntry: HashTableEntry): bool =
    if oldEntry.isEmpty:
        return true
    
    if sameUpperZobristKey(oldEntry.upperZobristKeyAndValue, newEntry.upperZobristKeyAndValue):
        return oldEntry.depth <= newEntry.depth

    let probability = if newEntry.nodeType == allNode and oldEntry.nodeType == cutNode:
        0.5
    else:
        1.0
    
    ht.randState.rand(1.0) < probability

func add*(
    ht: var HashTable,
    zobristKey: uint64,
    nodeType: NodeType,
    value: Value,
    depth: Ply,
    bestMove: Move
) =
    let entry = HashTableEntry(
        upperZobristKeyAndValue: (zobristKey and not sixteenBitMask) or (cast[uint64](value.int16) and sixteenBitMask),
        nodeType: nodeType,
        depth: depth,
        bestMove: bestMove
    )
    static: doAssert (valueInfinity <= int16.high.Value and -valueInfinity >= int16.low.Value)

    if nodeType == pvNode:
        withLock ht.pvTableMutex:
            if (not ht.pvNodes.hasKey(zobristKey)) or ht.pvNodes[zobristKey].entry.depth <= depth:
                ht.pvNodes[zobristKey] = CountedHashTableEntry(entry: entry, lookupCounter: 1)
    else:
        let i = zobristKey mod ht.nonPvNodes.len.uint64
        if ht.shouldReplace(entry, ht.nonPvNodes[i]):
            if ht.nonPvNodes[i].isEmpty:
                ht.hashFullCounter += 1
            ht.nonPvNodes[i] = entry

func get*(ht: var HashTable, zobristKey: uint64): HashTableEntry =
    
    if ht.pvNodes.hasKey(zobristKey):
        ht.pvNodes[zobristKey].lookupCounter += 1
        return ht.pvNodes[zobristKey].entry

    let i = zobristKey mod ht.nonPvNodes.len.uint64
    if not ht.nonPvNodes[i].isEmpty and sameUpperZobristKey(zobristKey, ht.nonPvNodes[i].upperZobristKeyAndValue):
        return ht.nonPvNodes[i]

    noEntry

func hashFull*(ht: HashTable): int =
    (ht.hashFullCounter * 1000) div ht.nonPvNodes.len
            
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


