#!/bin/bash -e

cd $(dirname $0)

. utils
. ../../environment

PROJECT=$(osc status | sed -n '1 { s/.* //; p; }')

if [ $PROJECT = $PROD ]; then
  REPLICAS=2
else
  REPLICAS=1
fi

osc create -f - <<EOF || true
kind: ImageStream
apiVersion: v1beta1
metadata:
  name: webserver
  labels:
    service: webserver
    function: application
EOF

osc create -f - <<EOF
kind: List
apiVersion: v1beta3
items:
- kind: DeploymentConfig
  apiVersion: v1beta1
  metadata:
    name: webserver
    labels:
      service: webserver
      function: application
  triggers:
  - type: ConfigChange
  - type: ImageChange
    imageChangeParams:
      automatic: true
      containerNames:
      - webserver
      from:
        name: webserver
      tag: latest
  template:
    strategy:
      type: Recreate
    controllerTemplate:
      replicas: $REPLICAS
      replicaSelector:
        service: webserver
        function: application
      podTemplate:
        desiredState:
          manifest:
            version: v1beta2
            containers:
            - name: webserver
              image: webserver:latest
              ports:
              - containerPort: 8080
              - containerPort: 8778
                name: jolokia
        labels:
          service: webserver
          function: application

- kind: Service
  apiVersion: v1beta3
  metadata:
    name: webserver
    labels:
      service: webserver
      function: application
  spec:
    ports:
    - port: 80
      targetPort: 8080
    selector:
      service: webserver
      function: application
EOF
