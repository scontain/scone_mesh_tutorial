#!/usr/bin/env bash

set -e

RED="\e[31m"
BLUE='\e[34m'
ORANGE='\e[33m'
NC='\e[0m' # No Color

# print an error message on an error exiting
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'if [ $? -ne 0 ]; then echo "${RED}\"${last_command}\" command failed - exiting.${NC}"; fi' EXIT

echo -e "${BLUE}Checking that we have access to sconectl${NC}"

if ! command -v sconectl &> /dev/null
then
    echo -e "${ORANGE}No sconectl found! Installing sconectl!${NC}"

    # ensure we have access to a new Rust installation

    if ! command -v rustup &> /dev/null
    then
        echo -e "${ORANGE}No Rust found! Installing Rust!${NC}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    else
        echo -e "${ORANGE}Ensuring Rust is up to date${NC}"
        rustup update
    fi

    cargo install sconectl
fi

echo -e "${BLUE}Checking that we have access to docker${NC}"

if ! command -v docker &> /dev/null
then
    echo -e "${RED}No docker found! You need to install docker or podman. EXITING.${NC}"
    exit 1
fi

echo -e "${BLUE}Checking that we have access to the base container image${NC}"

docker pull registry.scontain.com:5050/cicd/sconecli:latest 2> /dev/null || { 
    echo -e "${RED}You must get access to image `cicd/sconecli:latest`." 
    echo -e "Please send email info@scontain.com to ask for access${NC}"
    exit 1
}

echo -e "${BLUE}let's ensure that we build everything from scratch${NC}" 
rm -rf target

echo -e  "${BLUE}build service image"
echo -e  " - if the push fails, add --no-push or change the TO field${NC}"
 
sconectl apply -f service.yml 

echo -e "${BLUE}build application - push policies"
echo -e "  - this fails, if we have no access to the namespace"
echo -e "  - ensure to update the namespace to one that you control${NC}"

sconectl apply -f mesh.yml

echo -e "${BLUE}Uninstalling application in case it was previously installed - ignoring any errors${NC}"

helm uninstall pythonapp 2> /dev/null || true 

echo -e "${BLUE}install application"
echo -e " - this requires that kubectl gives access to you K8s cluster"
echo -e " - we first ensure that the old release is not running anymore${NC}"

helm install pythonapp target/helm/

echo -e "${BLUE}Check the logs by executing 'kubectl logs pythonapp<TAB>'"
echo -e "Uninstall by executign 'helm uninstall pythonapp'${NC}"
