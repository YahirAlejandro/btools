#!/bin/bash

set -e

check_existing_envs() {
  # Check if the file exists
  if [ -f "$1/$2" ]; then
    # Prompt the user to confirm deletion
    read -p "Env file exists, would you like to delete $2 in $1? [y/N] " confirm

    # If the user confirms, delete the file
    if [[ $confirm == "y" || $confirm == "Y" ]]; then
      rm "$1/$2"
      echo "Deleted $2 in $1"
      $3
    else
      echo "Cancelled deletion of $2 in $1"
    fi
  else
    # If the file doesn't exist, print an error message
    echo "Env file does not exist in $1, creating..."
    $3
  fi
}

create_mysql_envs() {
    echo "Creating new vars.env file for mysql"
    echo "MYSQL_ROOT_PASSWORD=$(openssl rand 64 | openssl enc -A -base64)" >> compose/mysql/vars.env
    echo "DEVICE_PATH=$(pwd)/mysql/data" >> compose/mysql/vars.env
}

create_budibase_envs() {
    echo "Creating new vars.env file for budibase"
    budibase_params="
      JWT_SECRET
      MINIO_ACCESS_KEY
      MINIO_SECRET_KEY
      REDIS_PASSWORD
      COUCHDB_USER
      COUCHDB_PASSWORD
      INTERNAL_API_KEY
    "

    for param in $budibase_params; do
        echo "Appending: $param"
        #echo "$param=$(openssl rand 64 | openssl enc -A -base64)" >> compose/budibase/vars.env
        echo "$param=$(openssl rand -hex 16)" >> compose/budibase/vars.env
    done
    echo "DEVICE_PATH=$(pwd)/budibase/data" >> compose/budibase/vars.env
}

replace_password() {
  # Create a random string
  random_string=$(openssl rand -hex 16)

  # Replace "password" with the random string in file1
  # https://singhkays.com/blog/sed-error-i-expects-followed-by-text/#the-fix
  sed -i'' -e "s/password/$random_string/g" "compose/mysql/docker-entrypoint-initdb.d/db.sql"

  sed -i'' -e "s/password/$random_string/g" "config.json"
}

hard_reset() {
  rm -rfv budibase/data/*.*
  rm -rfv mysql/data/*.*
  find . -name "vars.env" -delete

  backed_files="
    config.json-e
    db.sql-e
  "
  for file in "$backed_files"; do
    for f in $(find . -name "$file"); do
      if [ -f "${f}-e" ]; then
        rm "$f"
        mv "${f}-e" "$f"
      fi
    done
  done
exit
}

if [ "$1" == "--hard-reset" ]; then
  hard_reset
fi

echo "Checking if mysql env file exists"
check_existing_envs compose/mysql vars.env create_mysql_envs

echo "Checking if budibase env file exists"
check_existing_envs compose/budibase vars.env create_budibase_envs

echo "Replacing db passwords"
replace_password

echo "Running compose for mysql"

docker-compose -f compose/mysql/mysql-compose.yaml --env-file compose/mysql/vars.env up -d

echo "Running compose for budibase"
docker-compose -f compose/budibase/budibase-compose.yaml --env-file compose/budibase/vars.env up -d