#!/bin/bash

day=$(date +%A);
database="$1";
db_user="postgres";
db_host="127.0.0.1";
db_port=5432;
endfile="exported/databases/$database-$day.psql.gz";

if [[ $# -eq 0 ]] || [ $database == '-h' ] || [ $database == 'help' ]; then
  echo "
  Command to export the postgresql database.

  command: ./export-database.sh {database_name}
  example: ./export-database.sh mydatabase
  ";
  exit 1
fi


if [ $database ]; then
  echo "[i] Exporting the database, please wait...";
  echo "[i] starting time: $(date)";
  echo "[i] file target: $endfile";
  echo "....";

  pg_dump -U $db_user -h db_host -p db_port $database | gzip -c > $endfile;

  echo "";
  echo "[i] end time: $(date)";
  echo "";
fi
