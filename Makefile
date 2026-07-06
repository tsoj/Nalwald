EXE = Nalwald

ifdef EVALFILE
NIM_FLAGS += -d:evalFile=$(abspath $(EVALFILE))
endif

.PHONY: build
build:
	nimble build --nimbleDir:./nimbledeps $(NIM_FLAGS)
	[ "./bin/Nalwald" = "./$(EXE)" ] || mv ./Nalwald "$(EXE)"
