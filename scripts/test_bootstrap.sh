#!/bin/bash
TMP=$(mktemp -d)
trap "rm -rvf $TMP" EXIT

cp bootstrap $TMP/
cat <<EOF > $TMP/Dockerfile
FROM ubuntu:bionic
COPY bootstrap /bootstrap
RUN bash /bootstrap -y
EOF
cd $TMP
docker build . -t test_bootstrap
