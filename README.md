# Nalwald
#### Chess engine written in Nim
```
       __,      o     n_n_n   ooooo    + 
 o    /  o\    ( )    \   /    \ /    \ /
( )   \  \_>   / \    |   |    / \    ( )
|_|   /__\    /___\   /___\   /___\   /_\
```
You can play against Nalwald [here](https://lichess.org/@/squared-chess).
##### Download:
```
git clone https://gitlab.com/tsoj/Nalwald.git
```
##### Compile
You need the [Nim](https://nim-lang.org/) compiler (version 1.4.0 or higher) and the Clang compiler
```
nim c -d:danger -d:lto --passC:"-march=native" --passL:"-static" --cc:clang --threads:on Nalwald.nim
```
If you can't use the Clang compiler you can omit the `--cc:clang` flag, but it might result in a slower executable.

##### Run:
```
./Nalwald
```

##### Features

- evaluation:
  - king square contextual piece square tables
  - isolated pawns
  - pawn with two neighbors
  - passed pawns
  - mobility
  - sliding pieces attacking area around king
  - rook on open file
  - optimized using gradient descent
- search:
  - principle variation search
  - quiescence search
  - transposition table
  - move ordering:
    - transposition table suggested best move
    - static exchange evaluation
    - killermoves
    - history heuristic
  - nullmove reduction
  - late move reductions
  - check extensions
  - delta pruning
  - futility pruning

##### License

Copyright (c) 2021 Jost Triller
