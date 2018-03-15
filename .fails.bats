#!/usr/bin/env bats
PATH=/home/travis/build/joshuacox/kubash/bin:/home/travis/.kubash/bin:$PATH

@test "checkbashisms kubash" {
  result="$(checkbashisms -xnfp ./bin/kubash)"
  [ -z "$result" ]
}

@test "checkbashisms bootstrap" {
  result="$(checkbashisms -xnfp ./bootstrap)"
  [ -z "$result" ]
}
@test "checkbashisms scripts" {
  result="$(checkbashisms -xnfp ./scripts/*)"
  [ -z "$result" ]
}

@test "checkbashisms w8s" {
  result="$(checkbashisms -xnfp ./w8s/*)"
  [ -z "$result" ]
}
