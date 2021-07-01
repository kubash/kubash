#!/bin/bash
set -eux
TMP=$(mktemp -d)
RAND_TMP="$(uuidgen -r | sha256sum | base64 | head -c 8)"
trap "rm -rvf $TMP" EXIT

cp bootstrap $TMP/
cp templates/bashrc.tpl $TMP/.bashrc

cat <<EOF > $TMP/Dockerfile
FROM ubuntu:bionic
ENV TERM=dumb
COPY bootstrap /bootstrap
COPY .bashrc /root/.bashrc
RUN bash /bootstrap -y
EOF

cd $TMP
docker build . -t test_bootstrap
