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
              env:
              - name: JAVA_OPTS
                value: "-server -XX:+UseCompressedOops -verbose:gc -Xloggc:/opt/eap/standalone/log/gc.log -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=5 -XX:GCLogFileSize=3M -XX:-TraceClassUnloading -Xms128m -Xmx512m -XX:MaxPermSize=256m -Djava.net.preferIPv4Stack=true -Djboss.modules.system.pkgs=org.jboss.logmanager -Djava.awt.headless=true -Djboss.modules.policy-permissions=true -Xbootclasspath/p:/opt/eap/jboss-modules.jar:/opt/eap/modules/system/layers/base/org/jboss/logmanager/main/jboss-logmanager-1.5.4.Final-redhat-1.jar:/opt/eap/modules/system/layers/base/org/jboss/logmanager/ext/main/javax.json-1.0.4.jar:/opt/eap/modules/system/layers/base/org/jboss/logmanager/ext/main/jboss-logmanager-ext-1.0.0.Alpha2-redhat-1.jar -Djava.util.logging.manager=org.jboss.logmanager.LogManager -javaagent:/opt/eap/jolokia.jar=port=8778,host=0.0.0.0,discoveryEnabled=false"
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
