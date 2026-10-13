#!/usr/bin/env bats

@test "noble pax dir creation" {
  cd $HOME/.kubash
  rm -Rf pax/noble9.9.9test
  KUBASH_DIR=$HOME/.kubash ./scripts/noble 9.9.9test
  [ -e "pax/noble9.9.9test/noble9.9.9test-24.04-amd64.json" ]
  run grep -c REPLACEME pax/noble9.9.9test/noble9.9.9test-24.04-amd64.json
  [ "$output" = "0" ]
  run jq empty pax/noble9.9.9test/noble9.9.9test-24.04-amd64.json
  [ "$status" -eq 0 ]
  rm -Rf pax/noble9.9.9test
}
