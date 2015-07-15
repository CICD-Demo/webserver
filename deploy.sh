#!/bin/bash -e

cd $(dirname $0)

. utils
. ../../environment

PROJECT=$(oc status | sed -n '1 { s/.* //; p; }')

if [ $PROJECT = $PROD ]; then
  ROUTE=monster.$DOMAIN
  REPLICAS=2
else
  ROUTE=monster.$PROJECT.$DOMAIN
  REPLICAS=1
fi

oc create -f - <<EOF || true
kind: ImageStream
apiVersion: v1
metadata:
  name: webserver
  labels:
    service: webserver
    function: application
EOF

oc create -f - <<EOF
kind: List
apiVersion: v1
items:
- kind: DeploymentConfig
  apiVersion: v1
  metadata:
    name: webserver
    labels:
      service: webserver
      function: application
  spec:
    replicas: $REPLICAS
    selector:
      service: webserver
      function: application
    strategy:
      type: Recreate
    template:
      metadata:
        labels:
          service: webserver
          function: application
      spec:
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
    triggers:
    - type: ConfigChange
    - type: ImageChange
      imageChangeParams:
        automatic: true
        containerNames:
        - webserver
        from:
          kind: ImageStreamTag
          name: webserver:latest

- kind: Service
  apiVersion: v1
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

- kind: Route
  apiVersion: v1
  metadata:
    name: webserver
    labels:
      service: webserver
      function: application
  spec:
    host: $ROUTE
    to:
      kind: Service
      name: webserver
EOF
