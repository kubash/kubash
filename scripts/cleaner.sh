#!/bin/bash
: ${YESSIR:='false'}

remover () {
  TARGET=$1
  if [[ -f "$TARGET" ]]; then
    #echo rm -v $TARGET
    if [[ $YESSIR = 'true' ]]; then
      rm -v -f $TARGET
    else
      rm -v $TARGET
    fi
  else
    echo "warning: $TARGET not found"
  fi
}

sudo rm -f /usr/local/bin/arkade
sudo rm -f /usr/local/bin/ark

for i in $(cat bin/.gitignore)
do 
  remover "bin/$i"
done
