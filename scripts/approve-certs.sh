#!/bin/bash
kubectl get csr  --sort-by=.metadata.creationTimestamp \
  |grep Pending \
  |awk '{print $1}' \
  |xargs -I% kubectl certificate approve %  
