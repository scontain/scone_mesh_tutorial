#!/usr/bin/env bash

set -e

if [ ! -n "$RED" ]; then
  RED="\e[31m"
fi
if [ ! -n "BLUE" ]; then
  BLUE='\e[34m'
fi
if [ ! -n "ORANGE" ]; then
  ORANGE='\e[33m'
fi
if [ ! -n "NC" ]; then
  NC='\e[0m' # No Color
fi

# print an error message on an error exiting
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'if [ $? -ne 0 ]; then echo "${RED}\"${last_command}\" command failed - exiting.${NC}"; fi' EXIT


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
    exit 1
fi

echo -e "${BLUE}Checking that we have access to kubectl${NC}"
if ! command -v kubectl &> /dev/null
then
    echo -e "${RED}Command 'kubectl' not found!${NC}"
    echo -e "- ${ORANGE}Please install - see https://kubernetes.io/docs/tasks/tools/${NC}"
    exit 1
fi

echo -e "${BLUE}Checking that we have access to helm${NC}"
if ! command -v helm &> /dev/null
then
    echo -e "${RED}Command 'helm' not found!${NC}"
    echo -e "- ${ORANGE}Please install - see https://helm.sh/docs/intro/install/${NC}"
    exit 1
fi


