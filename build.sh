#!/usr/bin/env bash

set -e -x

export VERSION=${VERSION:-latest}
export CAS_VERSION=${CAS_VERSION:-$VERSION}
export HOST=${URL:-ceremony.scone.cloud}
export PORT=${HOST:-8094}
export URL="$HOST:$PORT"

export RED='\e[31m'
export BLUE='\e[34m'
export ORANGE='\e[33m'
export NC='\e[0m' # No Color

APP_NAMESPACE=""
source release.sh 2> /dev/null || true # get release name
export UPLOAD_MODE=${UPLOAD_MODE:-"SignOnline"} # EncryptedManifest

DEFAULT_NAMESPACE="" # Default Kubernetes namespace to use
export APP_IMAGE_REPO=${APP_IMAGE_REPO:=""} # Must be defined!
export SCONECTL_REPO=${SCONECTL_REPO:-"registry.scontain.com/cicd"}
export CEREMONY_CLIENT_PFX_KEY=${CEREMONY_CLIENT_PFX_KEY:-"1704221263011328318"}

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
release="$RELEASE"
export CAS=${CAS:="cas"}
export CAS_NAMESPACE=${CAS_NAMESPACE:="scone-system"}

error_exit() {
  trap '' EXIT
  echo -e "${RED}$1${NC}" 
  exit 1
}

usage ()
{
  echo ""
  echo "Usage:"
  echo "    build.sh [$ns_flag <kubernetes-namespace>] [$repo_flag <image repo>] [$release_flag <release name>] [$verbose_flag] [$help_flag]"
  echo ""
  echo ""
  echo "Builds a container image to build the confidential application. For example, use this image as part of your build pipeline."
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
    usage
    error_exit  "Error: You must specify a repo."
fi
export APP_IMAGE_REPO="${repo}"
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



# echo -e "${BLUE}let's ensure that we build everything from scratch${NC}" 
# rm -rf target || echo -e "${ORANGE} Failed to delete target directory - ignoring this! ${NC}"


echo -e  "${BLUE}building build image:${NC}"

SCONE="\$SCONE" envsubst < service.yaml.template > service.yaml

echo kubectl provision cas "$CAS" -n "$CAS_NAMESPACE" --print-public-keys

source <(VERSION="$CAS_VERSION" kubectl provision cas "$CAS" -n "$CAS_NAMESPACE" --print-public-keys || exit 1)

SCONE="\$SCONE" envsubst < mesh.yaml.template > mesh.yaml

cat > build_incontainer.sh  <<EOF
#!/usr/bin/env bash

set -e -x
export SCONECTL_REPO="$SCONECTL_REPO"
echo "127.0.0.1       $HOST" >> /etc/hosts
# create confidential service image
apply -f service.yaml $verbose $debug  --set-version ${VERSION}
# create confidential mesh
apply -f mesh.yaml --release "$RELEASE" $verbose $debug  --set-version ${VERSION} -vvv  --signing-url ${URL}
# copy generated helm chart
echo Copy target/helm to helm repo
EOF
chmod +x build_incontainer.sh

#  openssl s_client -showcerts -servername ceremony.scone.cloud -connect ceremony.scone.cloud:8008 2> /dev/null | openssl x509 > signing_server_cert.pem

cat > Dockerfile <<EOF
FROM $SCONECTL_REPO/sconecli:${VERSION}
COPY build_incontainer.sh /
COPY mesh.yaml /
COPY service.yaml /
COPY print_env.py /
COPY requirements.txt /
WORKDIR /
CMD bash /build_incontainer.sh
COPY rest_client_pfx.pfx /signing_client.pfx
COPY signing_server_cert.pem /signing_server_cert.pem
ENV CEREMONY_CLIENT_PFX_KEY="$CEREMONY_CLIENT_PFX_KEY"
EOF

export DOCKER_DEFAULT_PLATFORM=${DOCKER_DEFAULT_PLATFORM:-"linux/amd64"}

DOCKER_BUILDKIT=1 docker build --build-arg VERSION  --no-cache \
     --network=host --platform $DOCKER_DEFAULT_PLATFORM . -t scone_mesh_tutorial:build

echo "Run by executing"
docker run -it --net host --rm -v /var/run/docker.sock:/var/run/docker.sock     -v "$HOME/.docker:/root/.docker"     -v "$HOME/.cas:/root/.cas"     -v "$HOME/.scone:/root/.scone"     -w / scone_mesh_tutorial:build
