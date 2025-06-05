#!/bin/bash

# Parse command line arguments for language and version configuration
LANG_CODE="${LANG_CODE:-en}"
REMNAWAVE_BRANCH="${REMNAWAVE_BRANCH:-main}"
INSTALLER_BRANCH="${INSTALLER_BRANCH:-main}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --lang=*)
            LANG_CODE="${1#*=}"
            shift
            ;;
        --lang)
            LANG_CODE="$2"
            shift 2
            ;;
        --panel-branch=*)
            REMNAWAVE_BRANCH="${1#*=}"
            shift
            ;;
        --panel-branch)
            REMNAWAVE_BRANCH="$2"
            shift 2
            ;;
        --installer-branch=*)
            INSTALLER_BRANCH="${1#*=}"
            shift
            ;;
        --installer-branch)
            INSTALLER_BRANCH="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Color definitions for output
BOLD_BLUE=$(tput setaf 4)
BOLD_GREEN=$(tput setaf 2)
BOLD_YELLOW=$(tput setaf 11)
LIGHT_GREEN=$(tput setaf 10)
BOLD_BLUE_MENU=$(tput setaf 6)
ORANGE=$(tput setaf 3)
BOLD_RED=$(tput setaf 1)
BLUE=$(tput setaf 6)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
NC=$(tput sgr0)

# Script version
VERSION="1.5.1"

# Docker image tags based on branch
if [ "$REMNAWAVE_BRANCH" = "dev" ]; then
    REMNAWAVE_BACKEND_TAG="dev"
    REMNAWAVE_NODE_TAG="dev"
else
    REMNAWAVE_BACKEND_TAG="latest"
    REMNAWAVE_NODE_TAG="latest"
fi

# GitHub repository URLs
REMNAWAVE_BACKEND_REPO="https://raw.githubusercontent.com/remnawave/backend/refs/heads"
INSTALLER_REPO="https://raw.githubusercontent.com/xxphantom/remnawave-installer/refs/heads"

# Main directories
REMNAWAVE_DIR="/opt/remnawave"
REMNANODE_DIR="/opt/remnanode"
SELFSTEAL_DIR="/opt/remnanode/selfsteal"

# Local node directory (with panel)
LOCAL_REMNANODE_DIR="$REMNAWAVE_DIR/node"
