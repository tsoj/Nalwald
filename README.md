# Nalwald

### Chess engine written in Nim
![](./logo.svg)

### Download
```
git clone https://gitlab.com/tsoj/Nalwald.git
```
Pre-compiled executables for Windows and Linux can be found [here](https://gitlab.com/tsoj/Nalwald/-/releases).

### Compile

You need the [Nim](https://nim-lang.org/) compiler (version 1.9 or higher) and the Clang compiler.

**Compiling for native CPU**
```
nim native Nalwald.nim
```

**Compiling for generic CPUs**
```
nim default Nalwald.nim
```

**Compiling for modern CPUs (BMI2 and POPCNT)**
```
nim modern Nalwald.nim
```

### Features

- Evaluation:
  - King contextual piece square tables
  - Pawn contextual piece square tables
  - 3x3 pawn structure tables
  - Passed pawns
  - Mobility
  - Pieces attacking area around king
  - Rook on open file
  - Both bishops
  - Minor pieces forking major pieces
  - Pieces attacking other pieces
  - Tapered parameters
  - Optimized using gradient descent
- Search:
  - Principle variation search
  - Quiescence search
  - Transposition table
  - Move ordering:
    - Transposition table suggested best move
    - Static exchange evaluation
    - Killermoves
    - Relative and counter move history heuristic
  - Check extensions
  - Nullmove reduction
  - Late move reductions
  - Futility reductions
  - Hash result futility pruning
  - Delta pruning
  - Aspiration windows
  - Internal iterative reductions
- Multithreading support
- Supports Chess960/FRC
- Multi PV support
- UCI compatible
  - Additional commands: `moves`, `print`, `printdebug`, `fen`, `perft`, `test`, `eval`, `about`, `help`, `piecevalues`

### About

Nalwald is a Super GM level chess engine for classical and fischer random chess.
It supports the Universal Chess Interface (UCI), so it can be used with most
chess GUIs, such as Arena or Cute Chess. Nalwald is written in the programming
language Nim, which is a compiled language with an intuitive and clean syntax.

I began writing chess programs pretty much immediately after my first "Hello world!"
in 2016. My first big project was *jht-chess*, a chess playing program with
a console GUI for Linux. I used C++ but it looked more like messy C. Looking back
I would say that it is hard to write worse spaghetti code than I did then, but it
played good enough chess to win against amateur players. Since then, I wrote numerous
chess engine, most in C++ (*jht-chess*, *zebra-chess*, *jht-chess 2*, *squared-chess*,
and *Googleplex Starthinker*) but also one in Rust (*Hactar*) and now in Nim as well.
While my first chess engine could barely beat me (and I am not a very good chess
player, and was much less so in 2016), today Nalwald could beat Magnus Carlsen most
of the time.

On this journey from an at best mediocre chess program to a chess engine that can
win against the best humans players, the chessprogramming.org wiki and the
talkchess.com forum have been a great source of information and motivation. At
the beginning, the Wikipedia article "Schachprogramm" was really helpful, too.

During the development of Nalwald I also introduced some methods that I believe
are novelties in the chess programming space:
- *King contextual PSTs* are piece square tables that are different depending on
where our own king and the enemy king are located.
- *Pawn contextual PSTs* are piece square tables that are different depending on
where a pawn is. They are added together for all pawns.
- *Futility reductions* are an improvement to futility pruning. Here not only are moves
skipped that are likely to be much worse than alpha. Additionally, moves that are likely
slightly worse than alpha get their depth reduced accordingly to how bad they are
expected to be.
- *Hash result futility pruning* uses hash table entries that have not a depth high
enough to adjust alpha or beta, or to return a value immediately. Rather, depending
on their depth, the value gets only used, when the margin to alpha or beta is big
enough.
- *3x3 pawn structure tables* are a way to evaluate the structure of multiple pawns. For this a
3x3 mask is used on any square for which at least two pawns (ours or enemy) fall
into this mask. The pawns in that mask can be used to calculate an exact index for
this structure of pawns in a 3x3 space. This index can be used to access a table,
which contains values to evaluate this pawn structure. This table can then be
optimized using a method like gradient descent.

### Rating

| Version | CCRL 40/40 | CCRL 40/4 | CCRL 40/2 FRC | Release Date |
| :------ | ---------: | --------: | ------------: | -----------: |
| **Nalwald**                                                     |
| 17      |          – |         – |           – |              – |
| 16      |       2946 |      3012 |        2994 |  July 11, 2022 |
| 15      |       2881 |      2932 |        2921 |    Feb 8, 2022 |
| 14      |       2826 |         – |        2825 |   Sep 16, 2021 |
| 1.12    |          – |         – |        2736 |    Aug 9, 2021 |
| 1.11    |          – |      2813 |           – |  July 22, 2021 |
| 1.10    |          – |         – |           – |   July 3, 2021 |
| 1.9     |       2604 |      2673 |           – |  June 15, 2021 |
| 1.8.1   |          – |      2549 |           – | April 29, 2021 |
| 1.8     |          – |      2478 |           – | April 25, 2021 |
| **Googleplex Starthinker**                                      |
| 1.6     |       2393 |      2420 |           – |   Aug 16, 2019 |
| 1.4     |       2322 |      2289 |           – |   Dec 11, 2018 |
| **Squared-Chess**                                               |
| 1.3.0   |       2046 |      2147 |           – |   Nov 24, 2018 |
| 1.2.0   |       1980 |      1998 |           – |   Sep 24, 2018 |
| 1.1.0   |          – |      1987 |           – |   Sep 20, 2018 |
| **Hactar**                                                      |
| 0.9.0   |          – |      1352 |           – |   Jan 13, 2018 |

### License

Copyright © Jost Triller
