# Script to copy src files from codegen output folder to future-onboard-sw/codegen/nav_filter
# Created by PeterC, 20-08-2025

set -Eo pipefail

# Change folder to this script folder
THIS_SCRIPT_DIR="$(dirname "$(realpath "$0")")"
cd "$THIS_SCRIPT_DIR"

# Default values
TARGET_FOLDER=""
SRC_FOLDER_NAME=""
clean_target_folder_first=0

# Get options from shell
while getopts ":s:t:c" opt; do
  case $opt in
    s) SRC_FOLDER_NAME="$OPTARG"
    ;;
    t) TARGET_FOLDER="$OPTARG"
    ;;
    c) clean_target_folder_first=1
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

# Check if source and target folder names are given
if [ -z "$SRC_FOLDER_NAME" ] || [ -z "$TARGET_FOLDER" ]; then
  echo -e "\033[31mSource and target folder names must be provided.\033[0m"
  echo "Usage: $0 -s <source_folder_name> -t <target_folder> [-c]"
  echo "  -s : Name of the source folder"
  echo "  -t : Path to the target folder"
  echo "  -c : Optional flag to clean target folder before copying"
  exit 1
fi

# Check source folder exists
if [ ! -d "$SRC_FOLDER_NAME" ]; then
  echo -e "\033[31mSource folder does not exist: $SRC_FOLDER_NAME\033[0m"
  exit 1
fi

if [ "$clean_target_folder_first" -eq 1 ]; then
  echo -e "\033[34mCleaning target folder before transfer: $TARGET_FOLDER\033[0m"
  rm -rf $TARGET_FOLDER/*
fi

# Check target folder exist, else make it
if [ ! -d "$TARGET_FOLDER" ]; then
  echo -e "\033[34mTarget folder does not exist, creating: $TARGET_FOLDER\033[0m"
  mkdir -p "$TARGET_FOLDER"
fi

SRC_FOLDER=$SRC_FOLDER_NAME
echo -e "\033[34mCopying files src and headers: $SRC_FOLDER --> $TARGET_FOLDER\033[0m"

# Copy all headers .h and src .cpp or .c
shopt -s nullglob # Expand glob to nothing is no file with given extension exists

cd $SRC_FOLDER
rsync -av --update ./*.{h,c,cpp} "$THIS_SCRIPT_DIR/$TARGET_FOLDER/"
rsync -avR --update ./CMakeLists.txt "$THIS_SCRIPT_DIR/$TARGET_FOLDER/"
cd -