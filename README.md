# Nalwald

### Chess engine written in Nim
![](./logo.svg)

You can play against Nalwald [here](https://lichess.org/@/squared-chess).

#### Download:
```
git clone https://gitlab.com/tsoj/Nalwald.git
```
Pre-compiled executables for Windows and Linux can be found [here](https://gitlab.com/tsoj/Nalwald/-/releases).

#### Compile

You need the [Nim](https://nim-lang.org/) compiler (version 1.6 or higher) and the Clang compiler.

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
  - pawn structure masks
  - passed pawns
  - pawn attacking piece
  - mobility
  - sliding pieces attacking area around king
  - rook on open file
  - both bishops
  - minor pieces forking major pieces
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
    - relative and counter move history heuristic
  - check extensions
  - nullmove reduction
  - late move reductions
  - futility reductions
  - hash result futility pruning
  - delta pruning
  - fail-high delta pruning
- multithreading support
- supports Chess960/FRC
- multi PV
- UCI compatible
  - additional commands: `moves`, `print`, `printdebug`, `fen`, `perft`, `test`, `eval`, `about`, `help`. `piecevalues`, `pawnmask`

#### About

Nalwald is a Super GM level chess engine for classical and fischer random chess.
It supports the Universal Chess Interface (UCI), so it can be used with most
chess GUIs, such as Arena or Cute Chess. Nalwald is written in the programming
language Nim, which is a compiled language with an intuitive and clean syntax.

I began writing chess programs pretty much immediately after my first "Hello world!"
in 2016. My first big project was *jht-chess*, a chess playing program with
a console GUI for Linux. I used C++ but it looked more like messy C. Looking back
I would say that it is hard to write worse spaghetti code than I did then, but it
played good enough chess to win against amateur players. Since then, I wrote numerous
chess engine, most in C++ (*jht-chess*, *zebra-chess*, *jht-chess 2*, *square-chess*,
and *Googleplex Starthinker*) but also one in Rust (*Hactar*) and now in Nim as well.
While my first chess engine could barely beat me (I am not a very good chess
player, and much less so in 2016), today Nalwald could beat Magnus Carlsen most
of the time.

On this journey from an at best mediocre chess program to a chess engine that can
win against the best humans players, the chessprogramming.org wiki and the
talkchess.com forum have been a great source of information and motivation. At
the beginning, the Wikipedia article "Schachprogramm" was really helpful, too.

During the development of Nalwald I also introduced some methods that I believe
are novelties in the chess programming space:
- *King contextual PSTs* are piece square tables that are different depending on
where our own king and the enemy king are located.
- *Fail-high delta pruning* is an extension to delta pruning, where instead of pruning
hopelessly bad moves, moves are also pruned, if they are believed to be much better
than beta (by using the SEE function).
- *Futility reductions* are an improvement to futility pruning. Here not only are moves
skipped that are likely to be much worse than alpha. Additionally, moves that are likely
slightly worse than alpha get their depth reduced accordingly to how bad they are
expected to be.
- *Hash result futility pruning* uses hash table entries that have not a depth high
enough to adjust alpha or beta, or to return a value immediately. Rather, depending
on their depth, the value gets only used, when the margin to alpha or beta is big
enough.
- *Pawn structure masks* are a way to evaluate the structure of multiple pawns. For this a
3x3 mask is used on any square for which at least two pawns (ours or enemy) fall
into this mask. The pawns in that mask can be used to calculate an exact index for
this structure of pawns in a 3x3 space. This index can be used to access a table,
which contains values to evaluate this pawn structure. This table can then be
optimized using a method like gradient descent.

#### Rating

| Version | CCRL 40/40 | CCRL 40/4 | CCRL 40/2 FRC |
| :------ | ---------: | --------: | ------------: |
| **Nalwald** |
| 16      |          − |         − |          2995 |
| 15      |       2878 |      2902 |          2923 |
| 14      |       2826 |         − |          2826 |
| 1.12    |          − |         − |          2736 |
| 1.11    |          − |      2781 |             − |
| 1.9     |       2602 |      2637 |             − |
| 1.8.1   |          − |      2518 |             − |
| 1.8     |          − |      2449 |             − |
| **Googleplex Starthinker** |
| 1.6     |      2390 |       2391 |             − |
| 1.4     |      2321 |       2289 |             − |
| **Squared-Chess** |
| 1.3.0   |      2045 |       2090 |             − |
| 1.2.0   |      1979 |       1998 |             − |
| 1.1.0   |         − |       1987 |             − |
| **Hactar** |
| 0.9.0   |         − |       1411 |             − |

#### License

Copyright © Jost Triller
