#! /bin/bash

set -e  -x

# ensure we have access to sconectl

if ! command -v sconectl &> /dev/null
then
    echo "No sconectl found! Installing sconectl!"

    # ensure we have access to a new Rust installation

    if ! command -v rustup &> /dev/null
    then
        echo "No Rust found! Installing Rust!"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    else
        echo "Ensuring Rust is up to date"
        rustup update
    fi

    cargo install sconectl
fi

# ensure we have access to docker

if ! command -v docker &> /dev/null
then
    echo "No docker found! You need to install docker or podman. EXITING."
    exit 1
fi

# ensure we have access to the base container image

docker pull registry.scontain.com:5050/cicd/sconecli:latest 2> /dev/null || { 
    echo "You must get access to image `cicd/sconecli:latest`." 
    echo "Please send email info@scontain.com to ask for access"
    exit 1
}


# build service image
#  - if the push fails, add --no-push or change the TO field
 
sconectl apply -vvvv -f service.yml &> service.log

# build application - push policies
#  - this fails if we have no access to the namespace
#  - ensure to update the namespace to one that you control

sconectl apply -vvvv -f mesh.yml &> mesh.log

# install application
#  - this requires that kubectl gives access to you K8s cluster
#  - we first ensure that the old release is not running anymore

helm uninstall pythonapp 2> /dev/null || true 

# helm install pythonapp target/helm/
