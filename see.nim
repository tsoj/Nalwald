import
    types,
    move,
    position,
    positionUtils,
    evaluation,
    bitboard

func checkAssumptions(): bool =
    for piece in Piece.low..<Piece.high:
        var next = piece
        inc next
        if (king in [piece, next]) or (noPiece in [piece, next]):
            continue
        if piece.value > next.value:
            return false
    true
static: doAssert checkAssumptions()

func see(position: var Position, target: Square, victim: Piece, us: Color): Value =

    let attackers = position.attackers(us.opposite, target)
    for piece in (pawn, knight, bishop, rook, queen, king).fields:
        let attack = position[piece, us] and attackers
        if attack != 0:
            position.removePiece(us, piece, attack.toSquare)

            var
                collected = victim.value
                newVictim = piece
            
            when piece == pawn:
                if target notin a2..h7:
                    newVictim = queen
                    collected += queen.value - pawn.value
            
            return max(0, collected - position.see(target, newVictim, us.opposite))

func see*(position: Position, move: Move): Value =
    let
        us = position.us
        enemy = position.enemy
        source = move.source
        target = move.target
        moved = move.moved
        promoted = move.promoted

    var
        position = position
        currentVictim = moved

    position.removePiece(us, moved, source)

    if move.capturedEnPassant:
        position.removePiece(enemy, pawn, attackTablePawnQuiet[enemy][target].toSquare)
        position.removePiece(us, pawn, source)
    elif promoted != noPiece:
        position.removePiece(us, moved, source)
        result = promoted.value - pawn.value
        currentVictim = promoted
    else:
        position.removePiece(us, moved, source)

    result += move.captured.value - position.see(target, currentVictim, enemy)
                
proc seeTest*() =
    const data =
        [
            ("4R3/2r3p1/5bk1/1p1r3p/p2PR1P1/P1BK1P2/1P6/8 b - - 0 1", "h5g4", 0.Value),
            ("4R3/2r3p1/5bk1/1p1r1p1p/p2PR1P1/P1BK1P2/1P6/8 b - - 0 1", "h5g4", 0.Value),
            ("4r1k1/5pp1/nbp4p/1p2p2q/1P2P1b1/1BP2N1P/1B2QPPK/3R4 b - - 0 1", "g4f3", knight.value - bishop.value),
            ("2r1r1k1/pp1bppbp/3p1np1/q3P3/2P2P2/1P2B3/P1N1B1PP/2RQ1RK1 b - - 0 1", "d6e5", pawn.value),
            ("7r/5qpk/p1Qp1b1p/3r3n/BB3p2/5p2/P1P2P2/4RK1R w - - 0 1", "e1e8", 0.Value),
            ("6rr/6pk/p1Qp1b1p/2n5/1B3p2/5p2/P1P2P2/4RK1R w - - 0 1", "e1e8", -rook.value),
            ("7r/5qpk/2Qp1b1p/1N1r3n/BB3p2/5p2/P1P2P2/4RK1R w - - 0 1", "e1e8", -rook.value),
            ("6RR/4bP2/8/8/5r2/3K4/5p2/4k3 w - - 0 1", "f7f8q", bishop.value-pawn.value),
            ("6RR/4bP2/8/8/5r2/3K4/5p2/4k3 w - - 0 1", "f7f8n", knight.value-pawn.value),
            ("7R/4bP2/8/8/1q6/3K4/5p2/4k3 w - - 0 1", "f7f8r", -pawn.value),
            ("8/4kp2/2npp3/1Nn5/1p2PQP1/7q/1PP1B3/4KR1r b - - 0 1", "h1f1", 0.Value),
            ("8/4kp2/2npp3/1Nn5/1p2P1P1/7q/1PP1B3/4KR1r b - - 0 1", "h1f1", 0.Value),
            ("2r2r1k/6bp/p7/2q2p1Q/3PpP2/1B6/P5PP/2RR3K b - - 0 1", "c5c1", 2*rook.value-queen.value),
            ("r2qk1nr/pp2ppbp/2b3p1/2p1p3/8/2N2N2/PPPP1PPP/R1BQR1K1 w qk - 0 1", "f3e5", pawn.value),
            ("6r1/4kq2/b2p1p2/p1pPb3/p1P2B1Q/2P4P/2B1R1P1/6K1 w - - 0 1", "f4e5", 0.Value),
            ("3q2nk/pb1r1p2/np6/3P2Pp/2p1P3/2R4B/PQ3P1P/3R2K1 w - h6 0 1", "g5h6", 0.Value),
            ("3q2nk/pb1r1p2/np6/3P2Pp/2p1P3/2R1B2B/PQ3P1P/3R2K1 w - h6 0 1", "g5h6", pawn.value),
            ("2r4r/1P4pk/p2p1b1p/7n/BB3p2/2R2p2/P1P2P2/4RK2 w - - 0 1", "c3c8", rook.value),
            ("2r5/1P4pk/p2p1b1p/5b1n/BB3p2/2R2p2/P1P2P2/4RK2 w - - 0 1", "c3c8", rook.value),
            ("2r4k/2r4p/p7/2b2p1b/4pP2/1BR5/P1R3PP/2Q4K w - - 0 1", "c3c5", bishop.value),
            ("8/pp6/2pkp3/4bp2/2R3b1/2P5/PP4B1/1K6 w - - 0 1", "g2c6", pawn.value-bishop.value),
            ("4q3/1p1pr1k1/1B2rp2/6p1/p3PP2/P3R1P1/1P2R1K1/4Q3 b - - 0 1", "e6e4", pawn.value-rook.value),
            ("4q3/1p1pr1kb/1B2rp2/6p1/p3PP2/P3R1P1/1P2R1K1/4Q3 b - - 0 1", "h7e4", pawn.value),
            ("r1q1r1k1/pb1nppbp/1p3np1/1Pp1N3/3pNP2/B2P2PP/P3P1B1/2R1QRK1 w - c6 0 11", "b5c6", pawn.value),
            ("r3k2r/p1ppqpb1/Bn2pnp1/3PN3/1p2P3/2N2Q2/PPPB1PpP/R3K2R w QKqk - 0 2", "a6f1", pawn.value - bishop.value)
        ]
    for (fen, moveString, seeValue) in data:
        var position = fen.toPosition
        let move = moveString.toMove(position)
        doAssert position.fen == fen
        echo position.fen
        echo move
        let seeResult = position.see(move)
        echo seeResult, (if seeResult == seeValue: " == " else: " != "), seeValue
        doAssert seeResult == seeValue, "Failed see test"
    echo "Finished see test successfully"