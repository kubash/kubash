#!/usr/bin/env bash

do_kubegres () {
	if [[ -f .name-space ]]; then
		THIS_NAMESPACE=$(cat .name-space)
	else
		echo '.name-space file not found! exiting' 
		exit 1
	fi
	if [[ -f .cluster-name ]]; then
		THIS_CLUSTER=$(cat .cluster-name)
	else
		echo '.cluster-name file not found! exiting' 
		exit 1
	fi
	if [[ -f .default-storage-class ]]; then
		THIS_STORAGE_CLASS=$(cat .default-storage-class)
	else
		echo '.default-storage-class file not found! exiting' 
		exit 1
	fi

  KUBECONFIG=$KUBECONFIG \
  kubectl apply -f https://raw.githubusercontent.com/reactive-tech/kubegres/${KUBEGRES_VERSION}/kubegres.yaml
  ~/.kubash/w8s/generic.w8  kubegres-controller-manager kubegres-system

	if [[ -f $THIS_CLUSTER-postgres-secret.yaml ]]; then
    KUBECONFIG=$KUBECONFIG \
    kubectl apply -f $THIS_CLUSTER-postgres-secret.yaml
	else
    horizontal_rule
		echo "$THIS_CLUSTER-postgres-secret.yaml file not found! exiting" 
    horizontal_rule
# breaking indentation till EOF
cat <<EOF > $THIS_CLUSTER-postgres-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: $THIS_CLUSTER-postgres-secret
  namespace: default
type: Opaque
stringData:
  superUserPassword: postgresSuperUserPsw
  replicationUserPassword: postgresReplicaPsw
  myDbUserPassword: mydbpasw123 
EOF
    ls -alh $THIS_CLUSTER-postgres-secret.yaml
    horizontal_rule
		echo "^ an example file has been created for you $THIS_CLUSTER-postgres-secret.yaml"
    horizontal_rule
    echo 'Docs here --> https://www.kubegres.io/doc/getting-started.html'
		exit 1
	fi

	if [[ -f $THIS_CLUSTER-postgres-initdb.yaml ]]; then
    KUBECONFIG=$KUBECONFIG \
    kubectl apply -f $THIS_CLUSTER-postgres-initdb.yaml
	else
    horizontal_rule
		echo "$THIS_CLUSTER-postgres-initdb.yaml file not found! exiting" 
    horizontal_rule
# breaking indentation till EOF
cat <<EOF > $THIS_CLUSTER-postgres-initdb.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: $THIS_CLUSTER-postgres-conf
  namespace: $THIS_NAMESPACE

data:

  primary_init_script.sh: |
    #!/bin/bash
    set -e

    # This script assumes that the env-var $POSTGRES_MY_DB_PASSWORD contains the password of the custom user to create.
    # You can add any env-var in your Kubegres resource config YAML.

    dt=\$(date '+%d/%m/%Y %H:%M:%S');
    echo "$dt - Running init script the 1st time Primary PostgreSql container is created...";


    make_db () {
    customDatabaseName="\$1"
    customUserName="\$2"
    customPassword="\$3"

    echo "$dt - Running: psql -v ON_ERROR_STOP=1 --username \$POSTGRES_USER --dbname \$POSTGRES_DB ...";

    psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE \$customDatabaseName;
    CREATE USER \$customUserName WITH PASSWORD '\$customPassword';
    GRANT ALL PRIVILEGES ON DATABASE "\$customDatabaseName" to \$customUserName;
    EOSQL
    }

    make_db my_app_db my_username \$POSTGRES_MY_DB_PASSWORD
    make_db my_app_db2 my_username \$POSTGRES_MY_DB_PASSWORD

    echo "\$dt - Init script is completed";
EOF
    ls -alh $THIS_CLUSTER-postgres-initdb.yaml
    horizontal_rule
		echo "^ an example file has been created for you $THIS_CLUSTER-postgres-initdb.yaml"
    horizontal_rule
    echo 'Docs here --> https://www.kubegres.io/doc/getting-started.html'
		exit 1
	fi


	if [[ -f $THIS_CLUSTER-postgres.yaml ]]; then
    KUBECONFIG=$KUBECONFIG \
    kubectl apply -f $THIS_CLUSTER-postgres.yaml
	else
    horizontal_rule
		echo "$THIS_CLUSTER-postgres.yaml file not found! exiting" 
# breaking indentation till EOF
cat <<EOF > $THIS_CLUSTER-postgres.yaml
apiVersion: kubegres.reactive-tech.io/v1
kind: Kubegres
metadata:
  name: $THIS_CLUSTER-postgres
  namespace: $THIS_NAMESPACE

spec:

   replicas: ${POSTGRES_REPLICA_COUNT}
   image: ${POSTGRES_IMAGE_TAG}

   database:
      size: ${POSTGRES_DB_SIZE}
      storageClassName: $THIS_STORAGE_CLASS

   customConfig: $THIS_CLUSTER-postgres-conf

   env:
      - name: POSTGRES_PASSWORD
        valueFrom:
           secretKeyRef:
              name: $THIS_CLUSTER-postgres-secret
              key: superUserPassword

      - name: POSTGRES_REPLICATION_PASSWORD
        valueFrom:
           secretKeyRef:
              name: $THIS_CLUSTER-postgres-secret
              key: replicationUserPassword

      - name: POSTGRES_MY_DB_PASSWORD
        valueFrom:
           secretKeyRef:
              name: $THIS_CLUSTER-postgres-secret
              key: myDbUserPassword
EOF
    horizontal_rule
    ls -alh $THIS_CLUSTER-postgres.yaml
		echo "^ an example file has been created for you $THIS_CLUSTER-postgres.yaml"
    horizontal_rule
    echo 'Docs here --> https://www.kubegres.io/doc/getting-started.html'
		exit 1
	fi
}
