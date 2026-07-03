type
  Value* = float32
  Ply* = float32
  NodeType* = enum
    pvNode
    allNode
    cutNode

const
  exact* = pvNode
  upperBound* = allNode
  lowerBound* = cutNode
