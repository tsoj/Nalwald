EXE = Nalwald

.PHONY: build
build:
	nimble install nimchess@#head
	nimble build
	nim c -o:"$(EXE)" src/Nalwald.nim
