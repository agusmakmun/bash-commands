#!/bin/bash

args="$1";
env_path="$2";

if [[ $# -eq 0 ]] || [ $args == '-h' ] || [ $args == 'help' ]; then
  echo "
  Command to reconfigure the clean project.

  ./reconfigure.sh {args} {env_path}
  ./reconfigure.sh all ../../env-doain

  - 'args' is configuration mode,
           - pyc (to delete all *.pyc files in this project dir).
           - log (to delete all *.log files in this project dir).
           - dbs (to reconfigure new clean database migrations).
           - all (to reconfigure it all).

  - 'env_path' is python environtment path for this project.
               the endpoint of 'env_path' is without '/' slash.
               - ../../env-doain  (correct)
               - ../../env-doain/ (incorrect)
  ";
  exit 1
fi


function remove_pyc() {
  # delete all .pyc files
  echo '[i] deleting .pyc files...';
  find -name "*.pyc" -delete;
}

function remove_log() {
  # delete all log files
  echo '[i] deleting .log files...';
  find -name "*.log*" -delete;
}

function reconfigure_dbs() {
  # copying the configs.py file if doesn't exist
  if [ ! -f doa_app/configs.py ]; then
    echo '[i] reconfiguring configs.py file...';
    cp doa_app/configs.py.example doa_app/configs.py;
  fi

  # remove the database sqlite3
  if [ -e doa_app/db.sqlite3 ]; then
    echo '[i] deleting db.sqlite3...';
    rm doa_app/db.sqlite3;
  fi

  # activate the environtment
  local env_path=$env_path;
  source $env_path/bin/activate;

  # installing the requirements
  echo '[i] installing the requirements...';
  pip install -r requirements.txt;

  echo '[i] deleting migration files...';
  find . -path "*/migrations/*.py" -not -name "__init__.py" -not -name ".gitignore" -delete;
  find . -path "*/migrations/*.pyc" -delete;

  # reconfigure the migration files
  echo '[i] creating new migrations...';
  ./manage.py makemigrations;
  ./manage.py migrate --fake-initial;

  # create initial requirements
  echo '[i] creating new initial...';
  ./manage.py create_initial;

  # create superuser
  echo '[i] creating new superuser...';
  ./manage.py createsuperuser;
}


if [ $args ]; then
  if [ $args == 'pyc' ]; then
    remove_pyc;
  elif [ $args == 'log' ]; then
    remove_log;
  elif [ $args == 'dbs' ] && [ $env_path ]; then
    reconfigure_dbs;
  elif [ $args == 'all' ] && [ $env_path ]; then
    remove_pyc;
    remove_log;
    reconfigure_dbs;
  else
    echo "[!] Invalid argument"
    echo "[i] Try ./reconfigure -h for help"
  fi
fi
