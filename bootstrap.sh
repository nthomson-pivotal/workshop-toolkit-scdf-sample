#!/bin/bash

set -e

BIN_DIR=$CODER_DIR/bin

if [ ! -f "$BIN_DIR/cf" ]; then
  wget -O /tmp/cf.tgz https://s3-us-west-1.amazonaws.com/cf-cli-releases/releases/v6.46.0/cf-cli_6.46.0_linux_x86-64.tgz

  tar -zxf /tmp/cf.tgz cf

  mv cf $BIN_DIR/cf

  chmod +x $BIN_DIR/cf
fi

if [ ! -z "$CF_API" ]; then
  $BIN_DIR/cf login -a $CF_API -u admin -p $CF_PASSWORD --skip-ssl-validation -o system

  $BIN_DIR/cf apply-space -o workspaces $WORKSHOP_ID

  password=$(pwgen 8 1)

  $BIN_DIR/cf apply-user $WORKSHOP_ID $password
  $BIN_DIR/cf set-space-role $WORKSHOP_ID workspaces $WORKSHOP_ID SpaceDeveloper

  cat << EOF > /mnt/coder/bashrc.d/cf.bashrc
export CF_API=$CF_API
export CF_PASSWORD=$password
EOF
else
  cat << EOF > /mnt/coder/bashrc.d/cf.bashrc
echo "WARNING: CF CLI not logged in as administrator did not complete setup"
EOF
fi

chmod +x /mnt/coder/bashrc.d/cf.bashrc

SCDF_VERSION=2.3.1

wget -q https://github.com/spring-cloud/spring-cloud-dataflow/archive/v${SCDF_VERSION}.RELEASE.zip

unzip -qq v${SCDF_VERSION}.RELEASE.zip

pushd spring-cloud-dataflow-${SCDF_VERSION}.RELEASE/src/kubernetes
  kubectl apply -f rabbitmq
  
  kubectl apply -f mysql

  kubectl apply -f server/server-roles.yaml
  kubectl apply -f server/server-rolebinding.yaml
  kubectl apply -f server/service-account.yaml

  kubectl apply -f skipper/skipper-config-rabbit.yaml
  kubectl apply -f skipper/skipper-deployment.yaml
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: skipper
  labels:
    app: skipper
    spring-deployment-id: scdf
spec:
  ports:
  - port: 80
    targetPort: 7577
  selector:
    app: skipper
---
EOF

  kubectl apply -f server/server-deployment.yaml
  cat <<EOF | kubectl apply -f -
kind: Service
apiVersion: v1
metadata:
  name: scdf-server
  labels:
    app: scdf-server
    spring-deployment-id: scdf
spec:
  ports:
    - port: 80
      name: scdf-server
  selector:
    app: scdf-server
EOF
popd