---
apiVersion: openebs.io/v1alpha1
kind: StoragePoolClaim
metadata:
  name: cstor-kubash-pool
  annotations:
    cas.openebs.io/config: |
      - name: PoolResourceRequests
        value: |-
            memory: 5Gi
      - name: PoolResourceLimits
        value: |-
            memory: 5Gi
spec:
  name: cstor-kubash-pool
  type: disk
  maxPools: 3
  poolSpec:
    poolType: mirrored
---
