#!/bin/bash
# This is a full test of the bootstrap
set -eux
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

cp bootstrap $TMP/
cp templates/bashrc.tpl $TMP/.bashrc
cd ..
sudo cp -a .kubash $TMP/kubash
sudo chown -R ${USER}. $TMP/kubash

cat <<EOF > $TMP/Dockerfile
FROM ubuntu:bionic
ENV TERM=dumb
COPY kubash /root/.kubash
COPY .bashrc /root/.bashrc
COPY bootstrap /bootstrap
RUN bash /bootstrap -y
EOF

cd $TMP
docker build . -t test_bootstrap
