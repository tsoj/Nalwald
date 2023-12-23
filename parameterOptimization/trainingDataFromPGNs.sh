#!/bin/bash

set -e

# Check the number of arguments
if [ $# -ne 2 ]; then
  echo "Usage: $0 input.pgn output.epd"
  exit 1
fi

INPUT_PGN=$1
OUTPUT_EPD=$2

WORKDIR="workdir"

if [ -d "$WORKDIR" ]; then
  echo "Error: The directory $WORKDIR already exists."
  exit 1
fi

mkdir $WORKDIR

python3 ./genFenList.py $INPUT_PGN > $WORKDIR/full.epd

nim r removeNonQuietPositions.nim $WORKDIR/full.epd $WORKDIR/quiet.epd
nim r mergeDuplicateAndSelect.nim $WORKDIR/quiet.epd $OUTPUT_EPD 0.038

rm -rf $WORKDIR

echo "Finished :D"