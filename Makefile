EXE = Nalwald

.PHONY: build
build:
	nim c -o:"$(EXE)" src/Nalwald.nim
