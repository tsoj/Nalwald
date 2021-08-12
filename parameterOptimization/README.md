##### Generate positions
```
nim c -d:danger --gc:arc -d:lto --passL:"-static" --cc:clang --threads:on generatePositions.nim && ./generatePositions > unlabeledNonQuietSetNalwald.epd
```

##### Remove non-quiet positions

```
nim c -d:danger --gc:arc -d:lto --passL:"-static" --cc:clang --threads:on removeNonQuietPositions.nim && ./removeNonQuietPositions > unlabeledQuietSetNalwald.epd
```
##### Label positions

```
nim c -d:danger --gc:arc -d:lto --passL:"-static" --cc:clang --threads:on --run labelPositions.nim
```

##### Run optimization
```
nim c -d:danger --gc:arc -d:lto --passL:"-static" --cc:clang --threads:on --run optimization.nim
```

TODO: test if these all still work