<div align="center">
<p><h1>Nalwald</h1>
<i><h4>Chess engine written in Nim ♜</h4></i>
<img src="res/logo.png" width="384px" style="border-radius: 20px;">
</h1>
</div>

Nalwald is a superhuman chess engine for classical and fischer random chess. It supports the Universal Chess Interface (UCI), so it can be used with most chess GUIs, such as Arena or Cute Chess. Nalwald is written in the programming language Nim, a modern compiled systems language.

### Download
```
git clone https://github.com/tsoj/Nalwald.git
```
Pre-compiled executables for Windows and Linux can be found [here](https://github.com/tsoj/Nalwald/releases).

### Compile

You need the [Nim](https://nim-lang.org/) compiler (version 2.2.4 or higher) and the [Clang](https://clang.llvm.org/) compiler.

**Compiling for native CPU**
```bash
nimble build
```

**Compiling release builds**
```bash
nimble release
```

### Features

TODO

### About

I began writing chess programs pretty much immediately after my first "Hello world!" in 2016. My first big project was *jht-chess*, a chess playing program with a console GUI for Linux. I used C++ but it looked more like messy C. Looking back I would say that it's hard to write worse spaghetti code than I did then, but it played good enough chess to win against amateur players. Since then, I wrote numerous chess engines, most in C++ (*jht-chess*, *zebra-chess*, *jht-chess 2*, *squared-chess*, and *Googleplex Starthinker*) but also one in Rust (*Hactar*) and now in Nim as well. While my first chess engine could barely beat me (and I am not a very good chess player, and was much less so in 2016), today Nalwald would beat Magnus Carlsen almost every time.

On this journey from an at best mediocre chess program to a chess engine that can win against the best human players, the [chessprogramming.org](https://www.chessprogramming.org/Main_Page) wiki, the [talkchess.com](https://talkchess.com/forum3/index.php) forum, and the [Engine Programming Discord server](https://discord.com/invite/F6W6mMsTGN) have been a great source of information and motivation. At the beginning, the Wikipedia article "Schachprogramm" was really helpful, too.

Some noteworthy features of Nalwald:
TODO

### Rating

| Version | CCRL 40/40 | CCRL 40/4 | CCRL 40/2 FRC | Release Date |
| :------ | ---------: | --------: | ------------: | -----------: |
| **Nalwald**                                                     |
| 19      |       3306 |      3351 |        3438 |  July 11, 2024 |
| 18      |       3255 |      3286 |        3154 |   Aug 13, 2023 |
| 17.1    |       3188 |         – |           – |  June 20, 2023 |
| 17      |          – |      3201 |        3051 |   June 5, 2023 |
| 16      |       2974 |      3001 |        2995 |  July 11, 2022 |
| 15      |       2899 |      2913 |        2921 |    Feb 8, 2022 |
| 14      |       2840 |         – |        2821 |   Sep 16, 2021 |
| 1.12    |          – |         – |        2727 |    Aug 9, 2021 |
| 1.11    |          – |      2782 |           – |  July 22, 2021 |
| 1.10    |          – |         – |           – |   July 3, 2021 |
| 1.9     |       2594 |      2627 |           – |  June 15, 2021 |
| 1.8.1   |          – |      2496 |           – | April 29, 2021 |
| 1.8     |          – |      2416 |           – | April 25, 2021 |
| **Googleplex Starthinker**                                      |
| 1.6     |       2357 |      2347 |           – |   Aug 16, 2019 |
| 1.4     |       2279 |      2250 |           – |   Dec 11, 2018 |
| **Squared-Chess**                                               |
| 1.3.0   |       1979 |      2057 |           – |   Nov 24, 2018 |
| 1.2.0   |       1907 |      1850 |           – |   Sep 24, 2018 |
| 1.1.0   |          – |      1800 |           – |   Sep 20, 2018 |
| **Hactar**                                                      |
| 0.9.0   |          – |      1351 |           – |   Jan 13, 2018 |

### Other commands


**Generate training data**
TODO

**Create training data from PGNs**
TODO

**Optimize evaluation parameters**
TODO

**Optimize search parameters using weather-factory**
TODO

**Run SPRT test against the master branch**
TODO

**Run bench test against commit**
TODO

**Run tests**
TODO

### License

Nalwald © 2026 by Jost Triller is licensed under LGPLv3
