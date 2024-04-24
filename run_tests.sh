#!/bin/bash
set -e
nimble install taskpools@0.0.5
nim Nalwald.nims | grep -v "^Hint:" | cut -d' ' -f1 | xargs -I {} nim {} Nalwald.nims
find . -name *.nim -print0 | xargs -n 1 -0 nim check $1

# nim tests --run Nalwald.nims # TODO
echo -e "about\ntest 1000000\nquit\n" | nim debug --run Nalwald
echo -e "about\ntest 10000000\nquit\n" | nim native --run Nalwald