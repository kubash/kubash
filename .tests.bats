#!/usr/bin/env bats
PATH=/home/travis/build/joshuacox/kubash/bin:/home/travis/.kubash/bin:$PATH

@test "addition using bc" {
  result="$(echo 2+2 | bc)"
  [ "$result" -eq 4 ]
}

@test "ct" {
  [ -e "/home/travis/build/joshuacox/kubash/bin/ct" ]
}

@test "usetheforceyaml2cluster" {
  yamlresult="$(PATH=/home/travis/build/joshuacox/kubash/bin:/home/travis/.kubash/bin:$PATH kubash yaml2cluster /home/travis/build/joshuacox/kubash/examples/example-cluster.yaml -n example)"
  result2="$(cut -f2 -d, clusters/example/provision.csv|head -n1)"
  rm -Rf /home/travis/build/joshuacox/kubash/clusters/example
  [[ "$result2" == 'primary_master' ]]
}

@test "yaml2cluster" {
  yamlresult="$(kubash yaml2cluster /home/travis/build/joshuacox/kubash/examples/example-cluster.yaml -n example)"
  result2="$(cut -f2 -d, clusters/example/provision.csv|head -n1)"
  rm -Rf /home/travis/build/joshuacox/kubash/clusters/example
  [ "$result2" = 'primary_master' ]
}
