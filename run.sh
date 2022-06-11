#!/usr/bin/env bash

set -e

RED="\e[31m"
BLUE='\e[34m'
ORANGE='\e[33m'
NC='\e[0m' # No Color

RELEASE="pythonapp"

# print an error message on an error exit
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'if [ $? -ne 0 ]; then echo -e "${RED}\"${last_command}\" command failed - exiting.${NC}"; fi' EXIT

echo -e "${BLUE}Checking that we have access to sconectl${NC}"

if ! command -v sconectl &> /dev/null
then
    echo -e "${ORANGE}No sconectl found! Installing sconectl!${NC}"
    echo -e "${ORANGE}Ensuring that we have access to a new Rust installation${NC}"

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

if ! command -v kubectl &> /dev/null
then
    echo -e "${RED}Command 'kubectl' not found!${NC}"
    echo -e "- ${ORANGE}Please install - see https://kubernetes.io/docs/tasks/tools/${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null
then
    echo -e "${RED}Command 'helm' not found!${NC}"
    echo -e "- ${ORANGE}Please install - see https://helm.sh/docs/helm/helm_install/${NC}"
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


echo -e  "${BLUE}build service image:${NC} apply -f service.yaml"
echo -e  "${BLUE} - if the push fails, add --no-push to avoid pusing the image, or${NC}"
echo -e  "${BLUE}   change in file '${ORANGE}service.yaml${BLUE}' field '${ORANGE}build.to${BLUE}' to a container repo you have permission to push to.${NC}"

 
sconectl apply -f service.yaml


echo -e "${BLUE}build application and pushing policies:${NC} apply -f mesh.yaml"
echo -e "${BLUE}  - this fails, if you do not have access to the SCONE CAS namespace"
echo -e "  - update the namespace '${ORANGE}policy.namespace${NC}' to a unique name in '${ORANGE}mesh.yaml${NC}'"

sconectl apply -f mesh.yaml

echo -e "${BLUE}Uninstalling application in case it was previously installed:${NC} helm uninstall ${RELEASE}"
echo -e "${BLUE} - this requires that 'kubectl' gives access to a Kubernetes cluster${NC}"

helm uninstall ${RELEASE} 2> /dev/null || true 

echo -e "${BLUE}install application:${NC} helm install ${RELEASE} target/helm/"

helm install ${RELEASE} target/helm/

echo -e "${BLUE}Check the logs by executing:${NC} kubectl logs ${RELEASE}<TAB>"
echo -e "${BLUE}Uninstall by executing:${NC} helm uninstall ${RELEASE}"
