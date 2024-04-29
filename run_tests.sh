#!/bin/bash
set -e
nimble install malebolgia@1.3.2
nim Nalwald.nims | grep -v "^Hint:" | cut -d' ' -f1 | xargs -I {} nim {} Nalwald.nims
find . -name *.nim -print0 | xargs -n 1 -0 nim check $1
nim tests --run Nalwald.nims
nim testsDanger --run Nalwald.nims