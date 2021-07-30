import
    types,
    bitboard

type CastlingSide* = enum
  queenside, kingside

func connectOnFile(a,b: Square): Bitboard =
    result = 0
    if (ranks[a] and ranks[b]) != 0:
        var currentSquare = min(a, b)
        while true:
            result = result or bitAt[currentSquare]
            if currentSquare == max(a, b):
                break
            inc currentSquare

func blockSensitive(
    target: array[queenside..kingside, array[white..black, Square]]
): array[queenside..kingside, array[white..black, array[a1..h8, Bitboard]]] =
    for castlingSide in queenside..kingside:
        for us in white..black:
            for source in a1..h8:
                result[castlingSide][us][source] = connectOnFile(source, target[castlingSide][us])

const kingTarget* = [
    queenside: [white: c1, black: c8],
    kingside: [white: g1, black: g8]
]
const rookTarget* = [
    queenside: [white: d1, black: d8],
    kingside: [white: f1, black: f8]
]

# TODO: bring some consistency to this

const classicalRookSource* = [
    white: [queenside: a1, kingside: h1],
    black: [queenside: a8, kingside: h8]
]

const classicalKingSquare* = [white: e1, black: e8]

const blockSensitiveRook = blockSensitive(rookTarget)

const blockSensitiveKing = blockSensitive(kingTarget)

func blockSensitive*(castlingSide: CastlingSide, us: Color, kingSource, rookSource: Square): Bitboard =
    (
        blockSensitiveKing[castlingSide][us][kingSource] or
        blockSensitiveRook[castlingSide][us][rookSource]
    ) and not (bitAt[kingSource] or bitAt[rookSource])

const checkSensitive* = block:
    var checkSensitive: array[queenside..kingside, array[white..black, array[a1..h8, seq[Square]]]]

    for castlingSide in queenside..kingside:
        for us in white..black:
            for kingSource in a1..h8:
                var tmp =
                    blockSensitiveKing[castlingSide][us][kingSource] and
                    # I don't need to check if king will be in check after the move is done
                    (bitAt[kingSource] or not bitAt[kingTarget[castlingSide][us]])
                while tmp != 0:
                    checkSensitive[castlingSide][us][kingSource].add(tmp.removeTrailingOneBit.Square)

    checkSensitive