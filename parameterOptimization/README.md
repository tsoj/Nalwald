##### Generate positions
```
nim c -d:danger --gc:arc -d:lto --passL:"-static" --cc:clang --threads:on --run generatePositions.nim
```

##### Remove non-quiet positions

```
nim c -d:danger --gc:arc -d:lto --passL:"-static" --cc:clang --threads:on --run removeNonQuietPositions.nim
```
##### Label positions

Create an empty file called `quietSetNalwald.epd`.

```
mv quietSetNalwald.epd quietSetNalwald.epd.backup
touch quietSetNalwald.epd
```

Install [Psutil-Nim](https://github.com/johnscillieri/psutil-nim).

```
nimble install psutil
```

Label positions.

```
nim c -d:danger --gc:arc -d:lto --passL:"-static" --cc:clang --threads:on --run labelPositions.nim
```

##### Run optimization
```
nim c -d:danger --gc:arc -d:lto --passL:"-static" --cc:clang --threads:on --run optimization.nim
```

##### Get piece values
```
nim c -d:release --gc:arc -d:lto --passL:"-static" --cc:clang --run calculatePieceValue.nim
```