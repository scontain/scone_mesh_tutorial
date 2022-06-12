#!/usr/bin/env bash

set -e

RED="\e[31m"
BLUE='\e[34m'
ORANGE='\e[33m'
NC='\e[0m' # No Color

# print an error message on an error exiting
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'if [ $? -ne 0 ]; then echo "${RED}\"${last_command}\" command failed - exiting.${NC}"; fi' EXIT

# Check to make sure all prerequisites are installed
./check_prerequisites.sh

echo -e "${BLUE}let's ensure that we build everything from scratch${NC}"
rm -rf target

echo -e  "${BLUE}build service image"
echo -e  " - if the pull fails, you might not have access to image cicd/sconecli:latest. Please send email to info@scontain.com to ask for access."
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
