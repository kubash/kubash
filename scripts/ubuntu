#!/bin/bash
if [ $# -ne 1 ]; then
  # Print usage
  echo 'Error! wrong number of arguments'
  echo 'usage:'
  echo "$0 kube_version"
  exit 1
fi
KUBE_VERSION=$1
cp -av templates/ubuntu-kube.tpl pax/ubuntu${KUBE_VERSION}
cd pax/ubuntu${KUBE_VERSION}
mv ubuntuREPLACEME_KUBE_VERSION-16.04-amd64.json ubuntu${KUBE_VERSION}-16.04-amd64.json
sed -i "s/REPLACEME_KUBE_VERSION/${KUBE_VERSION}/g" ubuntu${KUBE_VERSION}-16.04-amd64.json
