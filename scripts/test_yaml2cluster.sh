#!/bin/bash
set -eux
TMP=$(mktemp -d)
TEST_CLUSTER_NAME=$(uuidgen -r | sha256sum | base64 | head -c 8)
trap "rm -rvf $TMP" EXIT

cp examples/example-cluster.yaml $TMP/
cp templates/test_yaml2cluster_answer $TMP/


cat <<EOF > $TMP/Dockerfile
FROM test_bootstrap
ENV TERM=dumb
COPY example-cluster.yaml /example-cluster.yaml
COPY test_yaml2cluster_answer /test_yaml2cluster_answer  
RUN cat /example-cluster.yaml
RUN /bin/bash -l -c "kubash yaml2cluster /example-cluster.yaml -n $TEST_CLUSTER_NAME"
#RUN ls -alhR /root/.kubash/clusters ; cat /root/.kubash/clusters/$TEST_CLUSTER_NAME/provision.csv
RUN diff /root/.kubash/clusters/$TEST_CLUSTER_NAME/provision.csv /test_yaml2cluster_answer 
EOF

cd $TMP
time docker build . -t test_yaml2cluster
