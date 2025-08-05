#!/bin/bash

echo "Cloning TC-CloudGames repositories with aliases..."
echo ""
echo ""

GITHUB_USER="rdpresser"

# Repository configuration with organized folders
declare -A REPOS=(
  ["tc-cloudgames-infra"]="infra:infrastructure"
  ["tc-cloudgames-apphost"]="apphost:orchestration"
  ["tc-cloudgames-users"]="users:services"
  ["tc-cloudgames-games"]="games:services"
  ["tc-cloudgames-payments"]="payments:services"
  ["tc-cloudgames-common"]="common:shared"
  ["tc-cloudgames-pipelines"]="pipelines:automation"
)

# Go back one level to the root directory
cd ..

# Create organizational directories if they don't exist
ORGANIZATIONAL_FOLDERS=("infrastructure" "orchestration" "services" "shared" "automation")
for org_folder in "${ORGANIZATIONAL_FOLDERS[@]}"; do
  if [ ! -d "$org_folder" ]; then
    mkdir -p "$org_folder"
    echo "Created directory: $org_folder"
  fi
done

echo ""

for repo_name in "${!REPOS[@]}"; do
  IFS=":" read -r alias parent_folder <<< "${REPOS[$repo_name]}"
  url="https://github.com/$GITHUB_USER/$repo_name.git"
  target_path="$parent_folder/$alias"
  
  echo "Cloning $repo_name as $target_path..."
  git clone "$url" "$target_path"
done

echo ""
echo ""
echo "All repositories have been cloned with their aliases."
