##### Generate positions
```
nim c -d:danger --gc:arc -d:lto --passL:"-static" --cc:clang --threads:on --run generatePositions.nim
```

##### Remove non-quiet positions

```
nim c -d:danger --gc:arc -d:lto --passL:"-static" --cc:clang --threads:on --run removeNonQuietPositions.nim
```
##### Label positions

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

TODO: test if these all still work