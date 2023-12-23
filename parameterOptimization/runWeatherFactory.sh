#!/bin/bash

set -e

MIN_NUM_GAMES=24
TC=8
HASH=32

if [ -d "./weather-factory" ]; then
    cd ./weather-factory
    git checkout main
    git pull
    cd ..
else
    git clone "https://github.com/jnlt3/weather-factory.git"
fi

cd ./weather-factory
mkdir tuner

cd ../../
nim native -o:./parameterOptimization/weather-factory/tuner/Nalwald Nalwald.nim
cd parameterOptimization/weather-factory

CUTECHESS_BINARY=$(whereis -b cutechess-cli)
CUTECHESS_BINARY=${CUTECHESS_BINARY#cutechess-cli: }

ln -s $CUTECHESS_BINARY ./tuner
cp ../Pohl.epd ./tuner

nim r ../../searchParams.nim > config.json

N_CORES=$(nproc)
N_CORES=$(($N_CORES - 1))
N_CORES=$(($N_CORES > 1 ? $N_CORES : 1))


if (( $N_CORES > 1 && $N_CORES % 2 != 0 )); then
  ((--N_CORES))
fi

N_GAMES=0


while (( $N_GAMES < $MIN_NUM_GAMES )); do
  N_GAMES=$(( $N_GAMES + $N_CORES ))
done



echo """{
    \"engine\": \"Nalwald\",
    \"book\": \"Pohl.epd\",
    \"games\": $N_GAMES,
    \"tc\": $TC,
    \"hash\": $HASH,
    \"threads\": $N_CORES
}""" > cutechess.json

