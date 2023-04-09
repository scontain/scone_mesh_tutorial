#!/usr/bin/env bash

set -e

export VERSION=${VERSION:-latest}

export RED='\e[31m'
export BLUE='\e[34m'
export ORANGE='\e[33m'
export NC='\e[0m' # No Color

APP_NAMESPACE=""
source release.sh 2> /dev/null || true # get release name


DEFAULT_NAMESPACE="" # Default Kubernetes namespace to use
export APP_IMAGE_REPO=${APP_IMAGE_REPO:=""} # Must be defined!
export SCONECTL_REPO=${SCONECTL_REPO:-"registry.scontain.com/sconectl"}

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
debug_flag="--debug"
debug_short_flag="-d"
debug=""
cas_flag="--cas"
cas_namespace_flag="--cas-namespace"

ns="$DEFAULT_NAMESPACE"
repo="$APP_IMAGE_REPO"
release="${RELEASE:=pythonapp}"
export CAS="cas"
export CAS_NAMESPACE="default"

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
  echo "Builds the application described in service.yaml.template and mesh.yaml.template and deploys"
  echo "it into your kubernetes cluster."
  echo ""
  echo "Options:"
  echo "    $ns_short_flag | $ns_flag"
  echo "                  The Kubernetes namespace in which the application should be deployed on the cluster."
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
  echo "    $debug_flag | debug_short_flag"
  echo "                  Create debug image instead of a production image"
  echo "    $cas_flag"
  echo "                  Set the name of the CAS service that we should use. Default is $CAS"
  echo "    $cas_namespace_flag"
  echo "                  Set the namespace of the CAS service that we should use. Default is $CAS_NAMESPACE"
  echo "    $help_flag"
  echo "                  Output this usage information and exit."
  echo ""
  echo "By default this uses the latest release of the SCONE Elements images: By setting environment variable"
  echo "   export VERSION=\"<VERSION>\""
  echo "you can select a different version. Currently selected version is $VERSION."
  echo "To use image from a different repository (e.g., a local cache), set "
  echo "   export SCONECTL_REPO (=\"$SCONECTL_REPO\")"
  echo "to the repo you want to use instead. Currently selected repo is $SCONECTL_REPO."
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
    ${repo_flag} | ${repo_short_flag})
      repo="$2"
      if [ ! -n "${repo}" ]; then
        usage
        error_exit "Error: The repo name '$repo' is invalid."
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
    ${debug_flag} | ${debug_short_flag})
      debug="--mode=debug"
      shift # past argument
      ;;
    ${cas_flag})
      export CAS="$2"
      if [ ! -n "${CAS}" ]; then
        usage
        error_exit "Error: The cas name '$CAS' is invalid."
      fi
      shift # past argument
      shift || true # past value
      ;;
    ${cas_namespace_flag})
      export CAS_NAMESPACE="$2"
      if [ ! -n "${CAS_NAMESPACE}" ]; then
        usage
        error_exit "Error: The cas namespace '$CAS_NAMESPACE' is invalid."
      fi
      shift # past argument
      shift || true # past value
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
    if [ "$APP_IMAGE_REPO" == "" ]; then
       usage
       error_exit  "Error: You must specify a repo."
    fi
else
    export APP_IMAGE_REPO="${APP_IMAGE_REPO:-$repo}"
fi
export RELEASE="$release"

if [ -z "$APP_NAMESPACE" ] ; then
    export APP_NAMESPACE="$RELEASE-$RANDOM-$RANDOM"
    echo -e "export APP_NAMESPACE=$RELEASE-$RANDOM-$RANDOM\n" >> release.sh  
else 
    echo "CAS Namespace already defined: $APP_NAMESPACE"
fi

if [  "${RELEASE}" == "" ]; then
    usage
    error_exit  "Error: You must specify a release using ${release_flag}."
fi

# Check to make sure all prerequisites are installed
a=0
while ! ./check_prerequisites.sh; do
    sleep 10;
    a=$[a+1];
    test $a -eq 10 && exit 1 || true;
done

echo -e "${BLUE}Checking that we have access to the base container image${NC}"

docker inspect $SCONECTL_REPO/sconecli:${VERSION} > /dev/null 2> /dev/null || docker pull $SCONECTL_REPO/sconecli:${VERSION} > /dev/null 2> /dev/null || { 
    echo -e "${RED}You must get access to image `${SCONECTL_REPO}/sconecli:${VERSION}`.${NC}" 
    error_exit "Please send email info@scontain.com to ask for access"
}


# echo -e "${BLUE}let's ensure that we build everything from scratch${NC}" 
# rm -rf target || echo -e "${ORANGE} Failed to delete target directory - ignoring this! ${NC}"


echo -e  "${BLUE}build service image:${NC} apply -f service.yaml"
echo -e  "${BLUE} - if the push fails, add --no-push to avoid pushing the image, or${NC}"
echo -e  "${BLUE}   change in file '${ORANGE}service.yaml${BLUE}' field '${ORANGE}build.to${BLUE}' to a container repo to which you have permission to push.${NC}"

SCONE="\$SCONE" envsubst < service.yaml.template > service.yaml

sconectl apply -f service.yaml $verbose $debug  --set-version ${VERSION}

echo -e "${BLUE}Determine the keys of CAS instance '$CAS' in namespace '$CAS_NAMESPACE'"

source <(VERSION="" kubectl provision cas "$CAS" -n "$CAS_NAMESPACE" --print-public-keys || exit 1)

echo -e "${BLUE}build application and pushing policies:${NC} apply -f mesh.yaml"
echo -e "${BLUE}  - this fails, if you do not have access to the SCONE CAS namespace"
echo -e "  - update the namespace '${ORANGE}policy.namespace${NC}' to a unique name in '${ORANGE}mesh.yaml${NC}'"

export CAS_URL="${CAS}.${CAS_NAMESPACE}"
SCONE="\$SCONE" envsubst < mesh.yaml.template > mesh.yaml

sconectl apply -f mesh.yaml --release "$RELEASE" $verbose $debug  --set-version ${VERSION}

echo -e "${BLUE}install/upgrade application:${NC} helm install ${namespace_args} ${RELEASE} target/helm/"

helm upgrade --install $namespace_arg ${release} target/helm/

namespace_args=`kubectl get pods -o name |grep -w $RELEASE`

echo -e "${BLUE}Check the logs by executing:${NC} kubectl logs ${namespace_args}"
echo -e "${BLUE}Uninstall by executing:${NC} helm uninstall ${RELEASE}"

APP_NAME="pythonservice" ./check_pods.sh

