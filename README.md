# Nalwald
#### Chess engine written in Nim
```
       __,      o     n_n_n   ooooo    + 
 o    /  o\    ( )    \   /    \ /    \ /
( )   \  \_>   / \    |   |    / \    ( )
|_|   /__\    /___\   /___\   /___\   /_\
```

##### Download:
```
git clone https://gitlab.com/tsoj/nalwald.git
```
##### Compile
You need a [Nim](https://nim-lang.org/) compiler and the Clang compiler
```
nim c -d:danger --passC:"-flto -march=native" --passL:"-flto" --cc:clang --threads:on Nalwald.nim
```
If you can't use the Clang compiler you can omit the `--cc:clang` flag, but it might cause the resulting binary to be slower.

##### Run:
```
./Nalwald
```

##### Features

- evaluation:
  - piece square tables
  - isolated pawns
  - passed pawns
  - mobility
  - rook on open file
  - rook on second rank/file of king
- search:
  - alpha-beta/negamax
  - principle variation search
  - quiescence search
  - transposition table
  - move ordering:
    - transposition table suggested best move
    - static exchange evaluation
    - killermoves
    - history heuristic
  - nullmove pruning
  - late move reductions
  - check extensions
  - delta pruning
  - futility pruning

##### License

Copyright (c) 2021 Jost Triller
