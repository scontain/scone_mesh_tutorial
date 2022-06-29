#!/usr/bin/env bash

set -e


RED="\e[31m"
BLUE='\e[34m'
ORANGE='\e[33m'
NC='\e[0m' # No Color

DEFAULT_NAMESPACE=""
RELEASE="pythonapp"

# print an error message on an error exit
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'if [ $? -ne 0 ]; then echo -e "${RED}\"${last_command}\" command failed - exiting.${NC}"; fi' EXIT

help_flag="--help"
ns_flag="--namespace"
ns_short_flag="-n"

ns=$DEFAULT_NAMESPACE

usage ()
{
  echo ""
  echo "Usage:"
  echo "    run.sh [$ns_flag kubernetes-namespace]"
  echo "           [$help_flag]"
  echo ""
  echo ""
  echo "Builds the application described in service.yaml and mesh.yaml and deploys"
  echo "it into your kubernetes cluster."
  echo ""
  echo "Options:"
  echo "    $ns_short_flag | $ns_flag:"
  echo "                  The namespace in which the application should be deployed on the cluster."
  echo "                  Default value:"
  echo "                      $DEFAULT_K8S_NAMESPACE"
  echo "    $help_flag:"
  echo "                  Output this usage information and exit."
  return
}

##### Parsing arguments

while [[ "$#" -gt 0 ]]; do
  case $1 in
    ${ns_flag} | ${ns_short_flag})
      ns="$2"
      if [ ! -n "${ns}" ]; then
        echo "Error: The namespace '$ns' is invalid."
        usage
        exit 1
      fi
      shift # past argument
      shift || true # past value
      ;;
    $help_flag)
      usage
      exit 0
      ;;
    *)
      echo "Error: Unknown parameter passed: $1";
      usage
      exit 1
      ;;
  esac
done

if [ ! -n "${ns}" ]; then
  namespace_arg=""
else
  namespace_arg="${ns_flag} ${ns} "
fi

# Check to make sure all prerequisites are installed
./check_prerequisites.sh

echo -e "${BLUE}Checking that we have access to the base container image${NC}"

docker pull registry.scontain.com:5050/cicd/sconecli:latest 2> /dev/null || { 
    echo -e "${RED}You must get access to image `cicd/sconecli:latest`." 
    echo -e "Please send email info@scontain.com to ask for access${NC}"
    exit 1
}


echo -e "${BLUE}let's ensure that we build everything from scratch${NC}" 
rm -rf target || echo -e "${ORANGE} Failed to delete target directory - ignoring this! ${NC}"


echo -e  "${BLUE}build service image:${NC} apply -f service.yaml"
echo -e  "${BLUE} - if the push fails, add --no-push to avoid pushing the image, or${NC}"
echo -e  "${BLUE}   change in file '${ORANGE}service.yaml${BLUE}' field '${ORANGE}build.to${BLUE}' to a container repo to which you have permission to push.${NC}"


sconectl apply -f service.yaml


echo -e "${BLUE}build application and pushing policies:${NC} apply -f mesh.yaml"
echo -e "${BLUE}  - this fails, if you do not have access to the SCONE CAS namespace"
echo -e "  - update the namespace '${ORANGE}policy.namespace${NC}' to a unique name in '${ORANGE}mesh.yaml${NC}'"

sconectl apply -f mesh.yaml

echo -e "${BLUE}Uninstalling application in case it was previously installed:${NC} helm uninstall ${namespace_args} ${RELEASE}"
echo -e "${BLUE} - this requires that 'kubectl' gives access to a Kubernetes cluster${NC}"

helm uninstall $namespace_arg ${RELEASE} 2> /dev/null || true

echo -e "${BLUE}install application:${NC} helm install ${namespace_args} ${RELEASE} target/helm/"

helm install $namespace_arg ${RELEASE} target/helm/

echo -e "${BLUE}Check the logs by executing:${NC} kubectl logs ${namespace_args} ${RELEASE}<TAB>"
echo -e "${BLUE}Uninstall by executing:${NC} helm uninstall ${namespace_args} ${RELEASE}"
