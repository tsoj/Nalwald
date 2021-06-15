##### Run optimization
```
nim c -d:danger -d:lto --passL:"-static" --cc:clang --threads:on --run optimization.nim
```