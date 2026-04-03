EXE = Nalwald

.PHONY: build
build:
	nimble build && nim c -o:"$(EXE)" src/Nalwald.nim
