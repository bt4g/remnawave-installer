#!/bin/bash

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
VERSION="1.5.0b"

# Main directories
REMNAWAVE_DIR="/opt/remnawave"
REMNANODE_DIR="/opt/remnanode"
SELFSTEAL_DIR="/opt/remnanode/selfsteal"

# Local node directory (with panel)
LOCAL_REMNANODE_DIR="$REMNAWAVE_DIR/node"
