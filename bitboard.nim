import types
import utils
import options
import bitops

type Bitboard* = uint64

func removeTrailingOneBit*(x: var SomeInteger): int =
    result = x.countTrailingZeroBits
    x = x and (x - 1)

const bitAt*: array[a1..h8, Bitboard] = block:
    var bitAt: array[a1..h8, Bitboard]
    for square in a1..h8:
        bitAt[square] = 1u64 shl square.int8
    bitAt

func bitboardString*(bitboard: Bitboard): string =
    boardString(proc (square: Square): Option[string] =
        if (bitAt[square] and bitboard) != 0:
            return some("●")
        none(string)
    )

const ranks*: array[a1..h8, Bitboard] = block:
    var ranks: array[a1..h8, Bitboard]
    for square in a1..h8:
        ranks[square] = 0b11111111u64 shl ((square.int8 div 8) * 8)
    ranks

const files*: array[a1..h8, Bitboard] = block:
    var files: array[a1..h8, Bitboard]
    for square in a1..h8:
        files[square] = 0b0000000100000001000000010000000100000001000000010000000100000001u64 shl (square.int8 mod 8)
    files


const mainDiagonal: Bitboard = 0b1000000001000000001000000001000000001000000001000000001000000001u64 # a1 to h9
const antiDiagonal: Bitboard = 0b0000000100000010000001000000100000010000001000000100000010000000u64 # h1 to a8

const upperLeftSideZero: Bitboard = 0b1000000011000000111000001111000011111000111111001111111011111111u64
const lowerLeftSideZero: Bitboard = 0b1111111111111110111111001111100011110000111000001100000010000000u64
const upperRightSideZero: Bitboard = 0b0000000000000001000000110000011100001111000111110011111101111111u64
const lowerRightSideZero: Bitboard = 0b0111111100111111000111110000111100000111000000110000000100000000u64

const diagonals*: array[a1..h8, Bitboard] = block:
    var diagonals: array[a1..h8, Bitboard]
    for i in 0..7:
        let currentDiagonal = (mainDiagonal shl i) and upperLeftSideZero
        var tmp = currentDiagonal
        while tmp != 0:
            diagonals[tmp.removeTrailingOneBit.Square] = currentDiagonal
    for i in 1..7:
        let currentDiagonal = (mainDiagonal shr i) and lowerRightSideZero
        var tmp = currentDiagonal
        while tmp != 0:
            diagonals[tmp.removeTrailingOneBit.Square] = currentDiagonal
    diagonals

const antiDiagonals: array[a1..h8, Bitboard] = block:
    var antiDiagonals: array[a1..h8, Bitboard]
    antiDiagonals[h8] = bitAt[h8]
    for i in 0..6:
        let currentAntiDiagonal = (antiDiagonal shl i) and lowerLeftSideZero
        var tmp = currentAntiDiagonal
        while tmp != 0:
            antiDiagonals[tmp.removeTrailingOneBit.Square] = currentAntiDiagonal
    for i in 1..7:
        let currentAntiDiagonal = (antiDiagonal shr i) and upperRightSideZero
        var tmp = currentAntiDiagonal
        while tmp != 0:
            antiDiagonals[tmp.removeTrailingOneBit.Square] = currentAntiDiagonal
    antiDiagonals

func hashkeyRank*(square: Square, occupancy: Bitboard): uint8 =
    (((occupancy.uint64 shr ((square.int8 div 8) * 8)) shr 1) and 0b111111).uint8
func hashkeyFile*(square: Square, occupancy: Bitboard): uint8 =
    ((((((occupancy shr (square.int8 mod 8)) and files[a1]) * mainDiagonal) shr 56) shr 1) and 0b111111).uint8
func hashkeyDiagonal*(square: Square, occupancy: Bitboard): uint8 =
    (((((occupancy and diagonals[square]) * files[a1]) shr 56) shr 1) and 0b111111).uint8
func hashkeyAntiDiagonal*(square: Square, occupancy: Bitboard): uint8 =
    (((((occupancy and antiDiagonals[square]) * files[a1]) shr 56) shr 1) and 0b111111).uint8

const possibleRankOccupancy: array[64, Bitboard] = block:
    var possibleRankOccupancy: array[64, Bitboard]
    for i in 0..63:
        let tmp: Bitboard = 0b10000001 or (i.Bitboard shl 1)
        possibleRankOccupancy[i] = 0
        for j in 0..7:
            possibleRankOccupancy[i] = possibleRankOccupancy[i] or (tmp shl (j * 8))
    possibleRankOccupancy

const possibleFileOccupancy: array[64, Bitboard] = block:
    var possibleFileOccupancy: array[64, Bitboard]
    for i in 0..63:
        func rankToFile(rank: Bitboard): Bitboard = (((rank and 0b11111111) * mainDiagonal) and files[h1]) shr 7
        let tmp: Bitboard = rankToFile(0b10000001 or (i.Bitboard shl 1))
        possibleFileOccupancy[i] = 0
        for j in 0..7:
            possibleFileOccupancy[i] = possibleFileOccupancy[i] or (tmp shl j)
    possibleFileOccupancy

func generateSlidingAttackTable[F](
    possibleOccupancy: array[64, Bitboard],
    directions: array[2, array[2, F]],
    hashkeyFunction: proc(square: Square, occupancy: Bitboard): uint8
    ): array[a1..h8, array[64, Bitboard]] =
    for square in a1..h8:
        for occupancy in possibleOccupancy:
            var attackMask: Bitboard = 0
            for goDirection in directions:
                var targetSquare = square
                while goDirection[0](targetSquare) and goDirection[1](targetSquare):
                    attackMask = attackMask or bitAt[targetSquare]
                    if (occupancy and bitAt[targetSquare]) != 0:
                        break;
            result[square][hashkeyFunction(square, occupancy)] = attackMask

const rankAttackTable: array[a1..h8, array[64, Bitboard]] = generateSlidingAttackTable(
    possibleRankOccupancy, [[goRight, goNothing], [goLeft, goNothing]], hashkeyRank)

const fileAttackTable: array[a1..h8, array[64, Bitboard]] = generateSlidingAttackTable(
    possibleFileOccupancy, [[goUp, goNothing], [goDown, goNothing]], hashkeyFile)

const diagonalAttackTable: array[a1..h8, array[64, Bitboard]] = generateSlidingAttackTable(
    possibleRankOccupancy, [[goUp, goRight], [goDown, goLeft]], hashkeyDiagonal)

const antiDiagonalAttackTable: array[a1..h8, array[64, Bitboard]] = generateSlidingAttackTable(
    possibleRankOccupancy, [[goUp, goLeft], [goDown, goRight]], hashkeyAntiDiagonal)

const knightAttackTable: array[a1..h8, Bitboard] = block:
    var knightAttackTable: array[a1..h8, Bitboard]
    for square in a1..h8:
        for directions in [
            [goUp, goLeft, goLeft], [goUp, goRight, goRight], [goUp, goUp, goLeft], [goUp, goUp, goRight],
            [goDown, goLeft, goLeft], [goDown, goRight, goRight], [goDown, goDown, goLeft], [goDown, goDown, goRight]
        ]:
            var targetSquare = square
            if directions[0](targetSquare) and directions[1](targetSquare) and directions[2](targetSquare):
                knightAttackTable[square] = knightAttackTable[square] or bitAt[targetSquare]
    knightAttackTable

const kingAttackTable: array[a1..h8, Bitboard] = block:
    var kingAttackTable: array[a1..h8, Bitboard]
    for square in a1..h8:
        for directions in [
            [goUp, goNothing], [goUp, goRight], [goUp, goLeft], [goLeft, goNothing],
            [goDown, goNothing], [goDown, goRight], [goDown, goLeft], [goRight, goNothing]
        ]:
            var targetSquare = square
            if directions[0](targetSquare) and directions[1](targetSquare):
                kingAttackTable[square] = kingAttackTable[square] or bitAt[targetSquare]
    kingAttackTable

const pawnQuietAttackTable*: array[white..black, array[a1..h8, Bitboard]] = block:
    var pawnQuietAttackTable: array[white..black, array[a1..h8, Bitboard]]
    for square in a1..h8:
        var targetSquare = square
        if targetSquare.goUp:
            pawnQuietAttackTable[white][square] = bitAt[targetSquare]
        targetSquare = square
        if targetSquare.goDown:
            pawnQuietAttackTable[black][square] = bitAt[targetSquare]
    pawnQuietAttackTable

const pawnCaptureAttackTable*: array[white..black, array[a1..h8, Bitboard]] = block:
    var pawnCaptureAttackTable: array[white..black, array[a1..h8, Bitboard]]
    for square in a1..h8:
        for direction in [goLeft, goRight]:
            var targetSquare = square
            if targetSquare.goUp and targetSquare.direction:
                pawnCaptureAttackTable[white][square] = pawnCaptureAttackTable[white][square] or bitAt[targetSquare]
            targetSquare = square
            if targetSquare.goDown and targetSquare.direction:
                pawnCaptureAttackTable[black][square] = pawnCaptureAttackTable[black][square] or bitAt[targetSquare]
    pawnCaptureAttackTable

const isPassedMask*: array[white..black, array[a1..h8, Bitboard]] = block:
    var isPassedMask: array[white..black, array[a1..h8, Bitboard]]
    for square in a1..h8:
        isPassedMask[white][square] = files[square]
        if not square.isLeftEdge:
            isPassedMask[white][square] = isPassedMask[white][square] or files[square.left]
        if not square.isRightEdge:
            isPassedMask[white][square] = isPassedMask[white][square] or files[square.right]
        isPassedMask[black][square] = isPassedMask[white][square]

        for j in 0..7:
            if j <= (square.int8 div 8):
                isPassedMask[white][square] = isPassedMask[white][square] and (not ranks[(j*8).Square])
            if j >= (square.int8 div 8):
                isPassedMask[black][square] = isPassedMask[black][square] and (not ranks[(j*8).Square])
    isPassedMask

const homeRank*: array[white..black, Bitboard] = [white: ranks[a1], black: ranks[a8]]
const pawnHomeRank*: array[white..black, Bitboard] = [white: ranks[a2], black: ranks[a7]]

func attackMaskKnight*(square: Square, occupancy: Bitboard): Bitboard =
    knightAttackTable[square]

func attackMaskBishop*(square: Square, occupancy: Bitboard): Bitboard =
    antiDiagonalAttackTable[square][hashkeyAntiDiagonal(square, occupancy)] or
    diagonalAttackTable[square][hashkeyDiagonal(square, occupancy)]

func attackMaskRook*(square: Square, occupancy: Bitboard): Bitboard =
    rankAttackTable[square][hashkeyRank(square, occupancy)] or
    fileAttackTable[square][hashkeyFile(square, occupancy)]

func attackMaskQueen*(square: Square, occupancy: Bitboard): Bitboard =
    antiDiagonalAttackTable[square][hashkeyAntiDiagonal(square, occupancy)] or
    diagonalAttackTable[square][hashkeyDiagonal(square, occupancy)] or
    rankAttackTable[square][hashkeyRank(square, occupancy)] or
    fileAttackTable[square][hashkeyFile(square, occupancy)]

func attackMaskKing*(square: Square, occupancy: Bitboard): Bitboard =
    kingAttackTable[square]

func attackMask*(piece: Piece, square: Square, occupancy: Bitboard): Bitboard {.inline.} =
    case piece:
    of knight:
        return attackMaskKnight(square, occupancy)
    of bishop:
        return attackMaskBishop(square, occupancy)
    of rook:
        return attackMaskRook(square, occupancy)
    of queen:
        return attackMaskQueen(square, occupancy)
    of king:
        return attackMaskKing(square, occupancy)
    else:
        assert false
