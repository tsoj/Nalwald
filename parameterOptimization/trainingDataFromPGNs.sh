#!/bin/bash

set -e

# Check the number of arguments
if [ $# -lt 3 ]; then
  echo "Usage: $0 output.epd input1.pgn input2.pgn ... inputN.pgn"
  exit 1
fi


WORKDIR="workdir"
OUTPUT_EPD=$1

if [ -d "$WORKDIR" ]; then
  echo "Error: The directory $WORKDIR already exists."
  exit 1
fi

touch $OUTPUT_EPD

echo "Output: $OUTPUT_EPD"

shift
for file in "$@"; do
  echo "Using $file"

  mkdir $WORKDIR
  python3 ./genFenList.py $file > $WORKDIR/full.epd

  #nim r removeNonQuietPositions.nim $WORKDIR/full.epd $WORKDIR/quiet.epd
  #nim r mergeDuplicateAndSelect.nim $WORKDIR/quiet.epd $OUTPUT_EPD 0.038
  nim r mergeDuplicateAndSelect.nim $WORKDIR/full.epd $WORKDIR/selected.epd 0.038
  
  cat $WORKDIR/selected.epd >> $OUTPUT_EPD
  rm -rf $WORKDIR
done

echo "Finished :D"