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

if ! command -v helm &> /dev/null
then
    echo -e "${RED}No helm found! You need to install helm. EXITING.${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null
then
    echo -e "${RED}No kubectl found! You need to install kubectl. EXITING.${NC}"
    exit 1
fi


