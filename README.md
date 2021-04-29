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
You need the [Nim](https://nim-lang.org/) compiler (version 1.2.0 or higher) and the Clang compiler
```
nim c -d:danger -d:lto --passC:"-march=native" --passL:"-static" --cc:clang --threads:on Nalwald.nim
```
If you can't use the Clang compiler you can omit the `--cc:clang` flag, but it might result in a slower executable.

If you are compiling on Windows and you want to use Clang then you need to replace `--passL:"-static"` with `--passL:"-static -fuse-ld=lld"`

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
