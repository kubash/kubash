#!/usr/bin/env bats

@test "trixie pax dir creation" {
  cd $HOME/.kubash
  rm -Rf pax/trixie9.9.9test
  KUBASH_DIR=$HOME/.kubash ./scripts/trixie 9.9.9test
  [ -e "pax/trixie9.9.9test/trixie9.9.9test-13-amd64.json" ]
  run grep -c REPLACEME pax/trixie9.9.9test/trixie9.9.9test-13-amd64.json
  [ "$output" = "0" ]
  run jq empty pax/trixie9.9.9test/trixie9.9.9test-13-amd64.json
  [ "$status" -eq 0 ]
  rm -Rf pax/trixie9.9.9test
}
