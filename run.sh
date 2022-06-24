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

# Check to make sure all prerequisites are installed
./check_prerequisites.sh

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
echo -e  "${BLUE}   change in file '${ORANGE}service.yaml${BLUE}' field '${ORANGE}build.to${BLUE}' to a container repo to which you have permission to push.${NC}"


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
