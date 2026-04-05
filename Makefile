EXE = Nalwald

.PHONY: build
build:
	nimble build --nimbleDir:./nimbledeps
	[ "./Nalwald" = "./$(EXE)" ] || mv ./Nalwald "$(EXE)"
