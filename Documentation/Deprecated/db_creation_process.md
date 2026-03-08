# DB Creation Process

## Start PostgreSQL

``` bash
psql postgres
```

## Create the role and the DB

``` sql
-- Create project role
CREATE ROLE myaccounting_user
    LOGIN
    PASSWORD 'dev_password'
    CREATEDB;

-- Create Database
CREATE DATABASE myaccounting_dev
    OWNER myaccounting_user;

\q
```

## Connect to the DB as your user

``` bash
psql -U myaccounting_user myaccounting_dev
```
