#!/bin/bash
if [ $# -ne 1 ]; then
  # Print usage
  echo -n 'Error! wrong number of arguments'
  echo " [$#]"
  echo 'usage:'
  echo "$0 KUBASH_DIR" 
  exit 1
fi
set -eux
TMP=$(mktemp -d)
KUBASH_DIR=$1
trap "rm -rvf $TMP" EXIT

cp examples/example-cluster.yaml $TMP/
cp ~/.kube/config $TMP/config

cat <<EOF > $TMP/start.sh
#!/bin/bash -l
export TERM=dumb
bats /root/.kubash/.ci/.tests.bats
EOF
chmod +x $TMP/start.sh


cat <<EOF > $TMP/Dockerfile
FROM test_yaml2cluster
RUN cd /root/.kubash; make bats
COPY start.sh /start.sh
RUN mkdir -p /root/.kube
COPY config /root/.kube/config
ENTRYPOINT /start.sh
EOF

cd $TMP
docker build . -t test_bats
docker run -it -v $KUBASH_DIR:/root/.kubash test_bats
