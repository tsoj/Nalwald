##### Generate positions
```
nim c --run generatePositions.nim
```

##### Remove non-quiet positions

```
nim c --run removeNonQuietPositions.nim
```

##### Merge duplicates and select random subset
```
nim c --run mergeDuplicateAndSelect.nim
```

##### Label positions

Create an empty file called `quietSetNalwald.epd`.

```
mv quietSetNalwald.epd quietSetNalwald.epd.backup
touch quietSetNalwald.epd
```

Label positions.

```
nim c --run labelPositions.nim
```

##### Run optimization
```
nim c --run optimization.nim
```

##### Get piece values
```
nim c --run calculatePieceValue.nim
```

##### How data sets are generated

###### quietSetZuri.epd

- quiet set from the Zurichess engine

###### quietSetNalwald.epd

- a number of random games are played, at random evaluation calls the positions are collected
- non-quiet and positions without legal moves are removed
- from the remaining games will be played one game each with Nalwald at ~80ms per move
- the result of that game will be the target value of the position

###### quietSmallNalwaldCCRL4040.epd

- a number of positions from CCRL4040 games are randomly selected (without early opening positions)
- non-quiet and positions without legal moves are removed
- from the remaining games will be played one game each with Nalwald at ~80ms per move
- the result of that game will be the target value of the position

###### quietSetCombinedCCRL4040.epd

- the target value of the positions of `quietSmallNalwaldCCRL4040.epd` will be averaged over the results of the respective CCRL4040 games (of players with Elo 2700 and higher) and the games that Nalwald played

###### quietLeavesSmallPoolGamesNalwaldSearchLabeled.epd
- randomly selected number of positions from games between Nalwald and other engines
- for each position made a search with 5000 nodes and selected ~2 leave node positions
- removed all non-quiet positions
- labeled positions with result of Nalwald search with 2,000,000 nodes

###### quietSmallPoolGamesNalwald2Labeled.epd
- removed non-quiet positions from games played between Nalwald and other engines
- randomly select 4,000,000 positions
- three copies of that set: labeled with original game result, labeled with Nalwald self-play result, labeled with search
- merge three copies

###### quietSmallPoolGamesNalwald2Labeled.epd
- removed non-quiet positions from games played between Nalwald and other engines
- randomly select 4,000,000 positions
- three copies of that set: labeled with original game result, labeled with Nalwald self-play result, labeled with search
- merge three copies

##### quietSmallPoolGamesNalwald3.epd, quietSmallPoolGamesNalwald4.epd
- removed non-quiet positions from games played between Nalwald and other engines
- randomly selected 1,500,000 (2,600,000 respectively) positions