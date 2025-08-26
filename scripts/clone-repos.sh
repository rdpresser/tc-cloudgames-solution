#!/bin/bash

echo "Cloning TC-CloudGames repositories with aliases..."
echo ""
echo ""

# Repository configuration
REPOS=(
  "tc-cloudgames-users:users:services"
  "tc-cloudgames-games:games:services"
  "tc-cloudgames-payments:payments:services"
  "tc-cloudgames-common:common:shared"
)

GITHUB_USER="rdpresser"

# Go back one level to the root directory
cd ..

# Create organizational directories if they don't exist
ORGANIZATIONAL_FOLDERS=("services" "shared")
for org_folder in "${ORGANIZATIONAL_FOLDERS[@]}"; do
  if [ ! -d "$org_folder" ]; then
    mkdir -p "$org_folder"
    echo "Created directory: $org_folder"
  fi
done

echo ""
echo ""

for repo_config in "${REPOS[@]}"; do
  IFS=":" read -r repo_name alias parent_folder <<< "$repo_config"
  url="https://github.com/$GITHUB_USER/$repo_name.git"
  target_path="$parent_folder/$alias"
  
  echo "Cloning $repo_name as $target_path..."
  git clone "$url" "$target_path"
done

echo ""
echo ""
echo "All repositories have been cloned with their aliases."
