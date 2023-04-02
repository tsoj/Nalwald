import
    ../searchParameters,
    ../types,
    ../position,
    ../positionUtils,
    game

func playGame(spA, spB: SearchParameters, startPosition: Position, nodesPerMove: int): float =
    result = 0.0
    for colorA in white..black:
        discard