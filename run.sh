#! /bin/sh

set -x -e


# ensure we have access to sconectl

if ! command -v sconectl &> /dev/null
then
    echo "No sconectl found! Installing sconectl!"

    # ensure we have access to a new Rust installation

    if ! command -v rustup /dev/null
    then
        echo "No Rust found! Installing Rust!"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    else
        echo "Ensuring Rust is up to date"
    fi

    cargo install sconectl
fi

# build service image
#  - if the push fails, add --no-push or change the TO field
 
sconectl apply -f service.yml 

# build application - push policies
#  - this fails if we have no access to the namespace
#  - ensure to update the namespace to one that you control

sconectl apply -f mesh.yml

# install application
#  - this requires that kubectl gives access to you K8s cluster
#  - we first ensure that the old release is not running anymore

helm uninstall pythonapp 2> /dev/null || true 

helm install pythonapp target/helm/
