#!/bin/bash

while true; do
  read -p "Enter the hex string (or type 'exit' to quit): " input
  if [[ "$input" == "exit" ]]; then
    echo "Goodbye!"
    break
  fi
  output=$(echo "$input" | grep -o .. | paste -sd' ' -)
  echo "$output"
done
