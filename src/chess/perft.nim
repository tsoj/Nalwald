import position, chessStrutils, move, movegen
import ../../tests/testData/exampleFens

func generateMovesViaPseudoLegalText(position: Position, moves: var openArray[Move]): int =
  static: assert sizeof(uint16) == sizeof(Move)
  result = 0
  for i in uint16.low .. uint16.high:
    let move = cast[Move](i)
    if position.isPseudoLegal(move):
      moves[result] = move
      result += 1

func perft*(position: Position, depth: int, printRootMoveNodes: static bool = false, usePseudoLegalTest: static bool = false): int64 =
  if depth <= 0:
    return 1
  var moves: array[320, Move]
  let numMoves = if usePseudoLegalTest: position.generateMovesViaPseudoLegalText(moves) else: position.generateMoves(moves)
  assert numMoves < 320
  for i in 0 ..< numMoves:
    template move(): Move =
      moves[i]

    let newPosition = position.doMove(move)
    if not newPosition.inCheck(position.us):
      let nodes = newPosition.perft(depth - 1)
      when printRootMoveNodes and not defined smallBuild:
        debugEcho "    ", move, " ", nodes, " ", newPosition.fen
      result += nodes
