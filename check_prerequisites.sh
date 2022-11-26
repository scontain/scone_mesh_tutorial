#!/usr/bin/env bash

set -e

export RED='\e[31m'
export BLUE='\e[34m'
export ORANGE='\e[33m'
export NC='\e[0m' # No Color


# print an error message on an error exiting
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'if [ $? -ne 0 ]; then echo "${RED}\"${last_command}\" command failed - exiting.${NC}"; fi' EXIT

function error_exit() {
  trap 'echo -e  "${RED}Exiting with error.${NC}"' EXIT
  exit 1
}

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
    if ! command -v cc &> /dev/null
    then
       echo -e "${RED} No (g)cc found! Installing sconectl is likely to fail!${NC}"
       echo -e "${ORANGE} On Ubuntu, you can install gcc as follows: sudo apt-get install -y build-essential ${NC}"
    fi
    cargo install sconectl
fi


echo -e "${BLUE}Checking that we have access to docker${NC}"
if ! command -v docker &> /dev/null
then
    echo -e "${RED}No docker found! You need to install docker or podman. EXITING.${NC}"
    error_exit
fi

echo -e "${BLUE}Checking that we run applications with docker without sudo${NC}"
if ! docker run -it --rm hello-world &> /dev/null
then
    echo -e "${RED}Docker does not seem to run."
    echo -e "Please ensure that you can run docker without sudo: https://docs.docker.com/engine/install/linux-postinstall/." 
    echo -e "Ensure that command 'docker run -it hello-world' runs without problems${NC}"
    error_exit
fi

echo -e "${BLUE}Checking that we can run container images for linux/amd64${NC}"
if ! docker run --platform linux/amd64 -it --rm hello-world &> /dev/null
then
    echo -e "${RED}Docker does not seem to support argument '--platform linux/amd64'"
    echo -e "Please ensure that you can run the latest version of docker (i.e.,  API version >= 1.40)" 
    VERSIONS=$(docker version | grep "API version" | awk '{ print $3}')
    for i in $VERSIONS ; do
      if [[ "$i" < "1.40" ]] ; then
        echo "Your docker API version is only '$i'."
        error_exit
      fi
    done
    echo -e "Please determine the version number with 'docker version' and update.${NC}"
    error_exit
fi

echo -e "${BLUE}Checking that you can pull the images ${NC}"
if docker pull --platform linux/amd64 -it registry.scontain.com/sconectl/check_cpufeatures:latest &> /dev/null
then
    echo -e "${RED}Docker does NOT seem to be able to pull the required container images.${NC}"
    echo -e "- ${ORANGE}1. Register an account with your company email at https://gitlab.scontain.com/users/sign_up.${NC}"
    echo -e "- ${ORANGE}2. Create an access token https://sconedocs.github.io/registry/#create-an-access-token${NC}"
    echo -e "- ${ORANGE}3. Log into your docker engine https://sconedocs.github.io/registry/#docker-login${NC}"
    echo -e "\n${RED}NOTE: ${ORANGE}If you registered with an anonymous email address or before fall 2022, we might not have\n      granted you access to all required images by default. Send us an email: info@scontain.com${NC}"
    error_exit
fi

echo -e "${BLUE}Checking that we the CPU has all necessary CPU features enabled${NC}"
if ! docker run --platform linux/amd64 -it --rm registry.scontain.com/sconectl/check_cpufeatures:latest &> /dev/null
then
    echo -e "${RED}Docker does not seem to support all CPU features.${NC}"
    echo -e "- ${ORANGE}Assuming you do not run on a modern Intel CPU. Please ensure that you pass the following options to qemu: -cpu qemu64,+ssse3,+sse3,+sse4.1,+sse4.2,+rdrand,+popcnt,+xsave,+aes${NC}" 
    error_exit
fi

echo -e "${BLUE}Checking that we have access to kubectl${NC}"
if ! command -v kubectl &> /dev/null
then
    echo -e "${RED}Command 'kubectl' not found!${NC}"
    echo -e "- ${ORANGE}Please install - see https://kubernetes.io/docs/tasks/tools/${NC}"
    error_exit
fi

echo -e "${BLUE}Checking that we have access to helm${NC}"
if ! command -v helm &> /dev/null
then
    echo -e "${RED}Command 'helm' not found!${NC}"
    echo -e "- ${ORANGE}Please install - see https://helm.sh/docs/intro/install/${NC}"
    error_exit
fi

echo -e "${BLUE}Checking that we have access to envsubst${NC}"
if ! command -v envsubst &> /dev/null
then
    echo -e "${RED}Command 'envsubst' not found!${NC}"
    echo -e "- ${ORANGE}Please install envsubst${NC}"
    error_exit
fi


echo -e "${BLUE}Checking that directory $HOME/.scone exits${NC}"
if [[ ! -e "$HOME/.scone" ]] ; then 
  echo -e " - Creating directory $HOME/.scone"
  mkdir -p "$HOME/.scone" ||  ( echo -e "${RED}Failed to create $HOME/.scone${NC}" ; error_exit)
fi

echo -e "${BLUE}Making sure that $HOME/.scone can be written by all. ${NC}"
echo -e "   ${BLUE}This is needed since we might have a different user ID inside of a container${NC}"
chmod 0777 "$HOME/.scone" ||  ( echo -e "${RED}Failed to create $HOME/.scone$.\n Maybe, run 'sudo chmod 0777 $HOME/.scone'{NC}" ; error_exit)


echo -e "${BLUE}Checking that you have access to a Kubernetes cluster. ${NC}"
if ! kubectl get pods &> /dev/null
then
    echo -e "${RED}It seems that you do not have access to a Kubernetes cluster!${NC}"
    echo -e "- ${ORANGE}Please ensure that you have access to a Kubernetes cluster${NC}"
fi


echo -e "${BLUE}Checking that you have the local attestation service, the SGX Plugin, and the image pull secrets installed${NC}"
#if ! sconectl scone_init &> /dev/null
if ! ((kubectl get las | grep HEALTHY) && (kubectl get cas | grep HEALTHY) && (kubectl get sgxplugin | grep HEALTHY))
then
    echo -e "${RED}It seems the Kubernetes cluster is not yet properly initialized!${NC}"
    echo -e "- ${ORANGE}1. Retrieve/create an access token https://sconedocs.github.io/registry/#create-an-access-token${NC}"
    echo -e "- ${ORANGE}2. Install the SCONE operator: https://sconedocs.github.io/2_operator_installation/"
    echo -e "- ${ORANGE}3. Install SGXPlugin, LAS, and CAS: https://sconedocs.github.io/4_quickstart/${NC}"
fi
