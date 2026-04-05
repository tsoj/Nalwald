EXE = Nalwald

.PHONY: build
build:
	nimble build --nimbleDir:./nimbledeps
	mv ./Nalwald "$(EXE)"
