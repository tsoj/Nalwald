import types
import move
import position
import tables

type
    HashTableEntry* = object
        zobristKey: uint64
        nodeType*: NodeType
        value*: Value
        depth*: Ply
        bestMove*: Move
    CountedHashTableEntry = object
        entry: HashTableEntry
        lookupCounter: uint32
    HashTable* = object
        nonPvNodes: seq[HashTableEntry]
        pvNodes: Table[uint64, CountedHashTableEntry]

const noEntry = HashTableEntry(zobristKey: 0, value: valueInfinity, bestMove: noMove)

template isEmpty*(entry: HashTableEntry): bool =
    entry == noEntry

func clear*(ht: var HashTable) =
    ht.pvNodes.clear
    for entry in ht.nonPvNodes.mitems:
        entry = noEntry

func newHashTable*(sizeInBytes: int): HashTable =
    let numEntries = sizeInBytes div sizeof(HashTableEntry)
    result.nonPvNodes = newSeq[HashTableEntry](numEntries)
    result.clear

func age*(ht: var HashTable)  =
    for (key, entry) in ht.pvNodes.mpairs:
        if entry.lookupCounter <= 0:
            ht.pvNodes.del(key)
        else:
            entry.lookupCounter = 0

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
        value: value,
        depth: depth,
        bestMove: bestMove
    )

    if nodeType == pvNode:
        if (not ht.pvNodes.hasKey(zobristKey)) or
        ht.pvNodes[zobristKey].entry.depth <= depth:
            ht.pvNodes[zobristKey] = CountedHashTableEntry(entry: entry, lookupCounter: 1)
    else:
        let i = zobristKey mod ht.nonPvNodes.len.uint64
        if ht.nonPvNodes[i].isEmpty or ht.nonPvNodes[i].zobristKey != zobristKey or ht.nonPvNodes[i].depth <= depth:
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


