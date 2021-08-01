# Nalwald
### Chess engine written in Nim
![](./logo.png)

You can play against Nalwald [here](https://lichess.org/@/squared-chess).
#### Download:
```
git clone https://gitlab.com/tsoj/Nalwald.git
```
Pre-compiled executables for Windows and Linux can be found [here](https://gitlab.com/tsoj/Nalwald/-/releases).
#### Compile

You need the [Nim](https://nim-lang.org/) compiler (version 1.5.1 2021-07-27 or higher) and the Clang compiler.

**Compiling for native CPU**
```
nim native Nalwald.nim
```

**Compiling for generic 64-bit CPUs**
```
nim default Nalwald.nim
```

**Compiling for modern 64-bit CPUs (BMI2 and POPCNT)**
```
nim modern Nalwald.nim
```

#### Features

- evaluation:
  - king square contextual piece square tables
  - isolated pawns
  - pawn with two neighbors
  - passed pawns
  - mobility
  - sliding pieces attacking area around king
  - rook on open file
  - both bishops
  - knight attacking bishop, rook, or queen
  - tapered parameters
  - optimized using gradient descent
- search:
  - principle variation search
  - quiescence search
  - transposition table
  - move ordering:
    - transposition table suggested best move
    - static exchange evaluation
    - killermoves
    - relative history heuristic
  - nullmove reduction
  - late move reductions
  - check extensions
  - delta pruning
  - fail-high delta pruning
  - futility reductions
  - hash result futility pruning
- supports Chess960/FRC

#### License

Copyright (c) 2021 Jost Triller
