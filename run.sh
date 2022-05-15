#! /bin/sh

set -x -e

# ensure we have access to sconectl
cargo install sconectl

# build service image
sconectl apply -f service.yml --no-push

# build application - push policies
#  - this fails if we have no access to the namespace
#  - ensure to update the namespace to one that you control

sconectl apply -f mesh.yml

# install application
#  - this requires that kubectl gives access to you K8s cluster

helm install pythonapp target/helm/charts/python_hello_user
