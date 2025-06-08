#!/bin/bash

# Create directory and generate selfsteal site
create_static_site() {
  local directory="$1"

  mkdir -p "$directory/html"

  # Change to the html directory to generate files there
  (
    cd "$directory/html"
    generate_selfsteal_form
  ) >/dev/null 2>&1 &

  download_pid=$!
  spinner !$download_pid "$(t spinner_downloading_static_files)"
}
