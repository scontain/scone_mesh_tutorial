#!/usr/bin/env bash

set -e


export RED='\e[31m'
export BLUE='\e[34m'
export ORANGE='\e[33m'
export NC='\e[0m' # No Color

source release.sh || true # get release name

DEFAULT_NAMESPACE="" # Default Kubernetes namespace to use
APP_IMAGE_REPO=${APP_IMAGE_REPO:=""} # Must be defined!

# print an error message on an error exit
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'if [ $? -ne 0 ]; then echo -e "${RED}\"${last_command}\" command failed - exiting.${NC}"; fi' EXIT

help_flag="--help"
ns_flag="--namespace"
ns_short_flag="-n"
repo_flag="--image_repo"
repo_short_flag="-i"
verbose_flag="-v"
verbose=""
release_flag="--release"
release_short_flag="-r"
verbose=""

ns="$DEFAULT_NAMESPACE"
repo="$APP_IMAGE_REPO"
release="$RELEASE"

error_exit() {
  trap '' EXIT
  echo -e "${RED}$1${NC}" 
  exit 1
}

usage ()
{
  echo ""
  echo "Usage:"
  echo "    run.sh [$ns_flag <kubernetes-namespace>] [$repo_flag <image repo>] [$release_flag <release name>] [$verbose_flag] [$help_flag]"
  echo ""
  echo ""
  echo "Builds the application described in service.yaml and mesh.yaml and deploys"
  echo "it into your kubernetes cluster."
  echo ""
  echo "Options:"
  echo "    $ns_short_flag | $ns_flag"
  echo "                  The namespace in which the application should be deployed on the cluster."
  echo "                  Default value: \"$DEFAULT_NAMESPACE\""
  echo "    $release_flag | $release_short_flag"
  echo "                  The helm release name of the application. "
  echo "                  Default value defined in file 'release.sh': RELEASE=\"$RELEASE\""
  echo "    $repo_short_flag | $repo_flag"
  echo "                  Container image repository to use for pushing the generated confidential image"
  echo "                  Default value is defined by environment variable:"
  echo "                    export APP_IMAGE_REPO=\"$APP_IMAGE_REPO\""
  echo "    $verbose_flag"
  echo "                  Enable verbose output"
  echo "    $help_flag"
  echo "                  Output this usage information and exit."
  return
}

##### Parsing arguments

while [[ "$#" -gt 0 ]]; do
  case $1 in
    ${ns_flag} | ${ns_short_flag})
      ns="$2"
      if [ ! -n "${ns}" ]; then
        usage
        error_exit "Error: The namespace '$ns' is invalid."
      fi
      shift # past argument
      shift || true # past value
      ;;
    ${release_flag} | ${release_short_flag})
      release="$2"
      if [ ! -n "${release}" ]; then
        usage
        error_exit "Error: The release name '$release' is invalid."
      fi
      shift # past argument
      shift || true # past value
      ;;
    ${verbose_flag})
      verbose="-vvvvvvvv"
      shift # past argument
      ;;
    $help_flag)
      usage
      exit 0
      ;;
    *)
      usage
      error_exit "Error: Unknown parameter passed: $1";
      ;;
  esac
done

if [ ! -n "${ns}" ]; then
    namespace_arg=""
else
    namespace_arg="${ns_flag} ${ns} "
fi

if [  "${repo}" == "" ]; then
    usage
    error_exit  "Error: You must specify a repo."
fi

# Check to make sure all prerequisites are installed
./check_prerequisites.sh

echo -e "${BLUE}Checking that we have access to the base container image${NC}"

docker inspect registry.scontain.com:5050/sconectl/sconecli:latest > /dev/null 2> /dev/null || docker pull registry.scontain.com:5050/sconectl/sconecli:latest > /dev/null 2> /dev/null || { 
    echo -e "${RED}You must get access to image `sconectl/sconecli:latest`.${NC}" 
    error_exit "Please send email info@scontain.com to ask for access"
}


echo -e "${BLUE}let's ensure that we build everything from scratch${NC}" 
rm -rf target || echo -e "${ORANGE} Failed to delete target directory - ignoring this! ${NC}"


echo -e  "${BLUE}build service image:${NC} apply -f service.yaml"
echo -e  "${BLUE} - if the push fails, add --no-push to avoid pushing the image, or${NC}"
echo -e  "${BLUE}   change in file '${ORANGE}service.yaml${BLUE}' field '${ORANGE}build.to${BLUE}' to a container repo to which you have permission to push.${NC}"

envsubst < service.yaml.template > service.yaml

sconectl apply -f service.yaml $verbose


echo -e "${BLUE}build application and pushing policies:${NC} apply -f mesh.yaml"
echo -e "${BLUE}  - this fails, if you do not have access to the SCONE CAS namespace"
echo -e "  - update the namespace '${ORANGE}policy.namespace${NC}' to a unique name in '${ORANGE}mesh.yaml${NC}'"

envsubst < mesh.yaml.template > mesh.yaml

sconectl apply -f mesh.yaml $verbose

echo -e "${BLUE}Uninstalling application in case it was previously installed:${NC} helm uninstall ${namespace_args} ${RELEASE}"
echo -e "${BLUE} - this requires that 'kubectl' gives access to a Kubernetes cluster${NC}"

helm uninstall $namespace_arg ${release} 2> /dev/null || true

echo -e "${BLUE}install application:${NC} helm install ${namespace_args} ${RELEASE} target/helm/"

helm install $namespace_arg ${release} target/helm/

echo -e "${BLUE}Check the logs by executing:${NC} kubectl logs ${namespace_args} ${RELEASE}<TAB>"
echo -e "${BLUE}Uninstall by executing:${NC} helm uninstall ${namespace_args} ${RELEASE}"
