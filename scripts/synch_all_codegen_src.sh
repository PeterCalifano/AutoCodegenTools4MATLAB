#! /bin/bash

# Call export_all_codegen_src.sh to export all codegen src files
# Created by PeterC, 23-09-2025
set -Eo pipefail

# Change folder to this script folder
THIS_SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$THIS_SCRIPT_DIR"

echo -e "\033[34mExecuting script in working directory: $THIS_SCRIPT_DIR...\033[0m"

# Check that "../future-onboard-sw" exists
if [ ! -d "../future-onboard-sw" ]; then
  echo -e "\033[31mError: ../future-onboard-sw folder does not exist. Please clone the future-onboard-sw repository at the same level of future-nav root first.\033[0m"
  exit 1
fi

src_folder_paths_list=(
  "cxx/filter_step"
  "cxx/moon_ip"
  "cxx_armv8/filter_step"
  "cxx_armv8/moon_ip"
)

target_folder_paths_list=(
  "../future-onboard-sw/codegen/nav_filter/src"
  "../future-onboard-sw/codegen/moon_ip/src"
  "../future-onboard-sw/codegen/nav_filter/src/arm_v8"
  "../future-onboard-sw/codegen/moon_ip/src/arm_v8"
)

# Loop over the arrays and call export_codegen_src.sh for each pair
for i in "${!src_folder_paths_list[@]}"; do
  src_folder_name="${src_folder_paths_list[$i]}"
  target_folder="${target_folder_paths_list[$i]}"
  echo "Exporting codegen sources from $src_folder_name to $target_folder"
  
  # If src of target folder does not exist, skip and print warning
  if [ ! -d "$src_folder_name" ]; then
    echo -e "\033[33mWarning: Source folder $src_folder_name does not exist. Skipping...\033[0m"
    continue
  fi

  if [ ! -d "$target_folder" ]; then
    echo -e "\033[33mWarning: Target folder $target_folder does not exist. Skipping...\033[0m"
    continue
  fi

  # Call the export script with the appropriate arguments
  bash export_codegen_src.sh -s $src_folder_name -t $target_folder
  
  if [ $? -ne 0 ]; then
    echo -e "\033[31mError: export_codegen_src.sh failed for $src_folder_name to $target_folder\033[0m"
    exit 1
  fi

done