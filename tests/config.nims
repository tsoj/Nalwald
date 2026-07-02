# begin Nimble config (version 2)
when withDir(thisDir(), system.fileExists("../nimble.paths")):
  include "../nimble.paths"
# end Nimble config

# The tests reuse test data (e.g. example FENs) from the nimchess repo,
# which is expected as a development dependency in vendor/nimchess.
when not system.dirExists(thisDir() & "/../vendor/nimchess/tests"):
  echo "Error: vendor/nimchess not found. The tests need the nimchess development"
  echo "dependency. Follow the \"Set up for development\" instructions in README.md:"
  echo "  nimble setup"
  echo "  nimble develop nimchess"
  quit 1

switch("path", "$projectDir/../vendor/nimchess/tests")
