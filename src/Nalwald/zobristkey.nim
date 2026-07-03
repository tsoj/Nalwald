import nimchess
import types
import std/random

const
  allZobristBitmasks = block:
    var
      randState = initRand(8767128)
      pieceBitmasks:
        array[white .. black, array[pawn .. king, array[a1 .. h8, ZobristKey]]]
      sideToMoveBitmasks: array[white .. black, ZobristKey]
      rookSourceBitmasks: array[Square, ZobristKey]

    for color in white .. black:
      for piece in pawn .. king:
        for square in a1 .. h8:
          pieceBitmasks[color][piece][square] = randState.next()

    for bitmask in sideToMoveBitmasks.mitems:
      bitmask = randState.next()

    for bitmask in rookSourceBitmasks.mitems:
      bitmask = randState.next()

    (
      pieces: pieceBitmasks,
      sideToMove: sideToMoveBitmasks,
      rookSource: rookSourceBitmasks,
    )

  zobristPieceBitmasks* = allZobristBitmasks.pieces
  zobristSideToMoveBitmasks* = allZobristBitmasks.sideToMove
  rookSourceBitmasks* = allZobristBitmasks.rookSource

func zobristKey*(position: Position): ZobristKey =
  result =
    position.enPassantTarget.ZobristKey xor zobristSideToMoveBitmasks[position.us]

  for color in white .. black:
    for piece in pawn .. king:
      for square in position[color, piece]:
        result = result xor zobristPieceBitmasks[color][piece][square]

    for side in queenside .. kingside:
      result = result xor rookSourceBitmasks[position.rookSource[color][side]]
