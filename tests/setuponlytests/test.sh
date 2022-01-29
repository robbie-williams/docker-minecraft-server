#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# go to script root directory
cd "$(dirname "$0")" || exit 1

# tests that only run the setup files for things like downloads and configuration.
setupOnlyMinecraftTest(){
  folder=$1
  cd "$folder"
  result=0

  if [ -f require.sh ]; then
    # require.sh scripts can check for environment variables, etc that are required for the test.
    # The script should exit with a non-zero status to indicate the test requirements are missing
    # and the test should be skipped
    if ! bash require.sh; then
      echo "${folder} SKIP"
      cd ..
      return 0
    fi
  fi

  if ! logs=$(docker-compose run mc 2>&1); then
    echo "${folder} test scenario FAILED"
    echo ":::::::::::: LOGS ::::::::::::::::
$logs
::::::::::::::::::::::::::::::::::
"
    result=1
  elif [ -f verify.sh ]; then
    if ! docker run --rm --entrypoint bash -v "${PWD}/data":/data -v "${PWD}/verify.sh":/verify "${IMAGE_TO_TEST:-itzg/minecraft-server}" /verify; then
      echo "${folder} verify FAILED"
      result=1
    else
      echo "${folder} verify PASS"
    fi
  else
    echo "${folder} PASS"
  fi

  docker-compose down -v --remove-orphans
  cd ..

  return $result
}

# go through each folder in setuponly and test setups
if (( $# > 0 )); then
  for folder in "$@"; do
    echo "Starting Tests in ${folder}"
    setupOnlyMinecraftTest "$folder"
  done
else
  readarray -t folders < <(find . -maxdepth 2 -mindepth 2 -name docker-compose.yml -printf '%h\n')
  for folder in "${folders[@]}"; do
    echo "Starting Tests in ${folder}"
    setupOnlyMinecraftTest "$folder"
  done
fi
