import types, zobristkey

import nimchess

import std/tables

type
  HashTableEntry* {.packed.} = object
    zobristKey: ZobristKey
    bestMove*: Move

  HashTable* = object
    table: seq[HashTableEntry]
    hashFullCounter: int64

const
  noEntry = HashTableEntry(zobristKey: 0, bestMove: noMove)
  megaByte* = 1024 * 1024
  defaultHashSizeMB* = 16

func clear*(ht: var HashTable) =
  for entry in ht.table.mitems:
    entry = noEntry
  ht.hashFullCounter = 0

func setLen*(ht: var HashTable, newLen: int) =
  ht.table.setLen(max(newLen, 10))
  ht.clear

func setByteSize*(ht: var HashTable, sizeInBytes: int) =
  let numEntries = sizeInBytes div sizeof(HashTableEntry)
  ht.setLen numEntries

func newHashTable*(len = 0): HashTable =
  result.table.setLen(len)

template isEmpty*(entry: HashTableEntry): bool =
  entry == noEntry

func add*(ht: var HashTable, zobristKey: ZobristKey, bestMove: Move) =
  let entry = HashTableEntry(zobristKey: zobristKey, bestMove: bestMove)

  doAssert ht.table.len > 0
  let i = zobristKey mod ht.table.len.ZobristKey
  if ht.table[i].isEmpty:
    ht.hashFullCounter += 1
  ht.table[i] = entry

func get*(ht: var HashTable, zobristKey: ZobristKey): HashTableEntry =
  doAssert ht.table.len > 0
  let i = zobristKey mod ht.table.len.ZobristKey
  if not ht.table[i].isEmpty and zobristKey == ht.table[i].zobristKey:
    return ht.table[i]

  noEntry

func hashFull*(ht: HashTable): int =
  (ht.hashFullCounter * 1000) div ht.table.len
