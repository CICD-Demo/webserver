#!/bin/bash -e

cd $(dirname $0)

. utils
. ../environment

osc create -f - <<EOF || true
kind: ImageStream
apiVersion: v1beta1
metadata:
  name: webserver
  labels:
    component: webserver
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
      component: webserver
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
      replicas: 1
      replicaSelector:
        component: webserver
      podTemplate:
        desiredState:
          manifest:
            version: v1beta2
            containers:
            - name: webserver
              image: webserver:latest
              ports:
              - containerPort: 8080
        labels:
          component: webserver

- kind: Service
  apiVersion: v1beta3
  metadata:
    name: webserver
    labels:
      component: webserver
  spec:
    ports:
    - port: 80
      targetPort: 8080
    selector:
      component: webserver
EOF
