#!/bin/bash

NAMESPACE="$ns"
if [[ "$NAMESPACE" == "" ]]; then
    NAMESPACE=default
fi
if [[ "$APP_NAME" == "" ]]; then
    APP_NAME=pythonservice
fi
if [[ "$RELEASE" == "" ]]; then
    RELEASE="mesh-tutorial"
fi

export POD=$(kubectl get pods --namespace $NAMESPACE -l "app.kubernetes.io/name=$APP_NAME,app.kubernetes.io/instance=$RELEASE" -o jsonpath="{.items[0].metadata.name}" 2> /dev/null)
export READY=$(kubectl get pod $POD -o jsonpath='{.status.containerStatuses[0].ready}' --namespace $NAMESPACE 2> /dev/null)

echo "Checking ready status of pod $POD:"
echo "  RELEASE:      $RELEASE"
echo "  APP_NAME:     $APP_NAME"
echo "  NAMESPACE:    $NAMESPACE"
echo "  READY STATUS: $READY"

I=0

while [[ "$READY" != "true"  ]] ; do
    ((I=I+1))
    if [[ $I -ge 64 ]] ; then
        echo "Giving up waiting for $POD to become 'ready'"
        exit 1
    fi
    sleep 5
    export POD=$(kubectl get pods --namespace $NAMESPACE -l "app.kubernetes.io/name=$APP_NAME,app.kubernetes.io/instance=$RELEASE" -o jsonpath="{.items[0].metadata.name}" 2> /dev/null)
    export READY=$(kubectl get pod $POD -o jsonpath='{.status.containerStatuses[0].ready}' --namespace $NAMESPACE 2> /dev/null)
    echo "  READY STATUS: $READY (POD=$POD)"
done

