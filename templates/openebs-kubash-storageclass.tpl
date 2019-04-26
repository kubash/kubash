apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: openebs-cstor-kubash
  annotations:
    cas.openebs.io/config: |
      - name: ReplicaCount
        value: "3"
    openebs.io/cas-type: cstor
provisioner: openebs.io/provisioner-iscsi
