import zobristkey, types

import nimchess

type SearchPos* = object
  pos*: Position
  zobristKey*: ZobristKey

func us*(position: SearchPos): Color =
  position.pos.us

func halfmoveClock*(position: SearchPos): int =
  position.pos.halfmoveClock

converter toPosition*(searchPos: SearchPos): lent Position =
  searchPos.pos

func searchPos*(position: Position): SearchPos =
  SearchPos(pos: position, zobristKey: position.zobristKey)

func updatedKey(key: ZobristKey, oldPos, newPos: Position): ZobristKey =
  result = key

  result =
    result xor zobristSideToMoveBitmasks[white] xor zobristSideToMoveBitmasks[black]

  result =
    result xor oldPos.enPassantTarget.ZobristKey xor newPos.enPassantTarget.ZobristKey

  for color in white .. black:
    for piece in pawn .. king:
      for square in oldPos[color, piece] xor newPos[color, piece]:
        result = result xor zobristPieceBitmasks[color][piece][square]

    for side in queenside .. kingside:
      result =
        result xor rookSourceBitmasks[oldPos.rookSource[color][side]] xor
        rookSourceBitmasks[newPos.rookSource[color][side]]

  assert result == newPos.zobristKey

func doMove*(searchPos: SearchPos, move: Move): SearchPos =
  result.pos = searchPos.pos.doMove(move)
  result.zobristKey = searchPos.zobristKey.updatedKey(searchPos.pos, result.pos)
