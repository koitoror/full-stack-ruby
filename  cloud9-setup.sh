#!/bin/sh

# Clean workspace
rm -rf *
rm .gitignore

# Upgrade Ruby
rvm install ruby-2.4.1 --default

# Start PostgreSQL and fix encoding conflict when creating database
sudo service postgresql start
psql -c "UPDATE pg_database SET datistemplate='false' WHERE datname='template1';" 
psql -c "DROP DATABASE template1;"
psql -c "CREATE DATABASE template1 encoding='UTF8' template template0;"
psql -c "UPDATE pg_database SET datistemplate='true' WHERE datname='template1';"