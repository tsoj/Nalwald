import types

import nimchess

import std/tables

type
  HashTableEntry* {.packed.} = object
    zobristKey: ZobristKey
    nodeType*: NodeType
    depth*: Ply
    bestMove*: Move

  HashTable* = seq[HashTableEntry]

const noEntry = HashTableEntry(zobristKey: 0, depth: 0.Ply, bestMove: noMove)

func clear*(ht: var HashTable) =
  for entry in ht.mitems:
    entry = noEntry

func setLen*(ht: var HashTable, newLen: int) =
  ht.setLen(max(newLen, 10))
  ht.clear

func setByteSize*(ht: var HashTable, sizeInBytes: int) =
  let numEntries = sizeInBytes div sizeof(HashTableEntry)
  ht.setLen numEntries

func newHashTable*(len = 0): HashTable =
  result.setLen(len)

template isEmpty*(entry: HashTableEntry): bool =
  entry == noEntry

func add*(
    ht: var HashTable,
    zobristKey: ZobristKey,
    nodeType: NodeType,
    value: Value,
    depth: Ply,
    bestMove: Move,
) =
  let entry = HashTableEntry(
    zobristKey: ZobristKey
    nodeType
    upperZobristKeyAndNodeTypeAndValue: (
      (zobristKey and not eighteenBitMask) or
      ((cast[uint64](nodeType.int64) shl 16) and eighteenBitMask and not sixteenBitMask) or
      (cast[uint64](value.int64) and sixteenBitMask)
    ),
    depth: depth,
    bestMove: bestMove,
  )
  doAssert entry.value == value
  doAssert entry.nodeType == nodeType
  doAssert sameUpperZobristKey(entry.upperZobristKeyAndNodeTypeAndValue, zobristKey)

  static:
    doAssert (valueInfinity <= int16.high.Value and -valueInfinity >= int16.low.Value)

  if nodeType == pvNode:
    withLock ht.pvTableMutex:
      if not ht.pvNodes.hasKey(zobristKey) or ht.pvNodes[zobristKey].entry.depth <= depth:
        ht.pvNodes[zobristKey] = CountedHashTableEntry(entry: entry, lookupCounter: 1)
  else:
    doAssert ht.nonPvNodes.len > 0
    let i = zobristKey mod ht.nonPvNodes.len.ZobristKey
    if ht.nonPvNodes[i].isEmpty:
      ht.hashFullCounter += 1
    ht.nonPvNodes[i] = entry

func get*(ht: var HashTable, zobristKey: ZobristKey): HashTableEntry =
  if ht.pvNodes.hasKey(zobristKey):
    withLock ht.pvTableMutex:
      if ht.pvNodes.hasKey(zobristKey):
        ht.pvNodes[zobristKey].lookupCounter += 1
        return ht.pvNodes[zobristKey].entry

  doAssert ht.nonPvNodes.len > 0
  let i = zobristKey mod ht.nonPvNodes.len.ZobristKey
  if not ht.nonPvNodes[i].isEmpty and
      sameUpperZobristKey(
        zobristKey, ht.nonPvNodes[i].upperZobristKeyAndNodeTypeAndValue
      ):
    return ht.nonPvNodes[i]

  noEntry

func hashFull*(ht: HashTable): int =
  (ht.hashFullCounter * 1000) div ht.nonPvNodes.len

func getPv*(ht: var HashTable, position: Position): seq[Move] =
  result = @[]

  var
    encounteredZobristKeys: seq[ZobristKey] = @[]
    currentPosition = position
  while true:
    if currentPosition.zobristKey in encounteredZobristKeys:
      return result
    encounteredZobristKeys.add(currentPosition.zobristKey)
    let entry = ht.get(currentPosition.zobristKey)

    if entry.isEmpty or not currentPosition.isLegal(entry.bestMove) or
        currentPosition.halfmoveClock >= 100:
      return result
    result.add(entry.bestMove)
    currentPosition = currentPosition.doMove(entry.bestMove)
