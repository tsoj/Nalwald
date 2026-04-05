EXE = Nalwald

.PHONY: build
build:
	nimble setup
	nimble develop nimchess
	nim c -o:"$(EXE)" src/Nalwald.nim
