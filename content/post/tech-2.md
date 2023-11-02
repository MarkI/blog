---
date: 2019-05-10T00:00:00-00:00
description: "SQL Script Testing as part of your Pipeline"
featured_image: ""
tags: []
title: "SQL Script Testing as part of your Pipeline"
draft: false
---

In all my time with working with SQL Scripts I have not come across a way to test them as part of a CI pipeline. With the release of SQL Server for Linux it has become a reality. Last year I worked on a strategy to spin up a database, use it for testing, and then destroy it.

All of this could be achieved using MS SQL backups and restores. However, this is quite slow and requires access to a server running MS SQL where you have admin rights to restore and delete a database.

With a new DevOps approach that would more closely match what is in production I decided to investigate using Microsoft's docker image for MS SQL. The process is such that you are always working with a database that matches the database structure that is in production. All new SQL scripts are tested in order against this database so that you can have a greater level of confidence that it is going to work immediately in production.

The steps for testing the database scripts are as follows:

1. Start a SQL docker container with a database structure that matches production.
1. Start a Flyway docker container with the SQL scripts folder mapped into the container.
1. Execute the Flyway command to update the database that was started in step 1.
1. Cleanup (i.e. remove SQL and Flyway containers).



## Running SQL Server inside of Docker


You do not need to install SQL Server on your local development machine in order to run a local development database.

You can run SQL Server as a docker container. The advantages of this is that if you no longer need SQL then you can just remove the docker container.

Prerequisites:

* Windows 10 / MacOS / Linux
* Docker (e.g. Docker for Windows or Docker for Mac)

The command to run the default SQL Server docker image locally:

```docker
docker run -d -p 1433:1433 --name sql-linux -e ACCEPT_EULA=Y -e SA_PASSWORD=Passw0rd microsoft/mssql-server-linux
```

Now it's a simple case of using SQL Server Management Studio to connect to SQL Server. We are not too concerned about the SQL admin password as this is a temporary throwaway database. We would never expose or use such a simple password in production.


## Creating a Docker Image with an Empty Database

If we are starting a new project or retrofitting this to an existing project, we first need a docker image with an empty database.
We are going to use docker to create a new image with our empty database.

Files required to create the docker images:

* Dockerfile: Dockerfile to create the docker image.
* SqlCmdScript.sql: SQL Script to create empty database and default database user.
* SqlCmdStartup.sh: Shell script to execute the SQL script.
* entrypoint.sh: Shell script for entry point into docker image.

Dockerfile containing the following:

```docker
FROM microsoft/mssql-server-linux

ENV ACCEPT_EULA Y
ENV SA_PASSWORD Passw0rd

# copy from host to container
COPY ./entrypoint.sh ./SqlCmdStartup.sh ./SqlCmdScript.sql ./

RUN chmod +x ./SqlCmdStartup.sh

CMD /bin/bash ./entrypoint.sh
```

SqlCmdScript.sql
```sql
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'database-name')
  CREATE database database-name;
GO

-- Create the default dB user
USE [master]
GO

IF NOT EXISTS(SELECT 1 FROM [database-name].sys.database_principals WHERE name = 'user-name')
  CREATE LOGIN [user-name] WITH PASSWORD=N'user-password', DEFAULT_DATABASE=[database-name], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO

USE [database-name]
GO

IF NOT EXISTS(SELECT 1 FROM [database-name].sys.database_principals WHERE name = 'user-name')
BEGIN
  CREATE USER [user-name] FOR LOGIN [user-name]
  ALTER USER [user-name] WITH DEFAULT_SCHEMA=[dbo]
  ALTER ROLE [db_owner] ADD MEMBER [user-name]
END
GO
```

SqlCmdStartup.sh

```bash
#!/bin/bash

# wait for the SQL Server to come up
sleep 10s

# run the script to create the DB
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P Passw0rd -d master -i SqlCmdScript.sql
# run any other scripts
# /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P Passw0rd -d master -i CleanupScript.sql
```

entrypoint.sh
```bash
#!/bin/bash

#start the script to create the DB and then start the sqlserver
./SqlCmdStartup.sh & /opt/mssql/bin/sqlservr
```

Once you have the required files you can execute the following docker command to create the new docker image:

```docker
docker build -t db-image-name .
```

## Baseline the Database using Flyway

Now that the image exists with the empty database, use flyway to baseline the empty database.

Run the docker container for the newly created database image. The database needs to be running for the Flyway baseline process.

```docker
docker run -d -p 1433:1433 --name db-container-name db-image-name
```

Execute the following docker command to run the flyway baseline command:

```docker
docker run --rm boxfuse/flyway -url="jdbc:sqlserver://local-ip:1433;databaseName=database-name" -user=sa -password=Passw0rd baseline
```

Using docker to execute flyway enables the use flyway without having to install it locally or on the build server.

Once the baseline has been completed, the container needs to be committed to an image using the following command:

```docker
docker commit db-container-name db-image-name:baseline
docker tag db-image-name:baseline db-image-name:latest
```

Publish the baseline database to a docker repository for later retrieval and use. The publish command is as follows:

```docker
docker push db-image-name:baseline
docker push db-image-name:latest
```

## Migrate the Database using Flyway
Now that there is a baseline database, flyway can be used to run the database script files using the flyway migrate command.

Assuming there is a folder named "db" containing your database scripts. Use the following command to execute a flyway migration:

```docker
# Run flyway to update the database
docker run --rm -v ./db:/flyway/sql boxfuse/flyway -url='jdbc:sqlserver://db-server-ip;databasename=database-name' -user=${db_user} -password=${db_password} migrate
```

## Simplify your Script Testing using Docker Compose

Docker compose requires a yml configuration file. The yml file will contain 2 services (the database and flyway services).

```docker-compose
version: '3'
services:
  # Database service
  db:
    image: db-image-name:latest

  # Database schema update service
  flyway:
    image: boxfuse/flyway
    command: -url="jdbc:sqlserver://db;databaseName=database-name" -user=sa -password=Passw0rd migrate
    volumes:
      - ./db:/flyway/sql
    depends_on:
      - db
```

There are 3 steps in the testing process using docker-compose:

1. Start the database then wait for it to complete the startup
```docker
docker-compose -f docker-compose.db.yml up -d --force-recreate db
```
2. Run flyway
```docker
docker-compose -f docker-compose.db.yml up flyway
```

3. Cleanup
```docker
docker-compose -f docker-compose.db.yml down --rmi all
```

Combining the  above into a single command would look as follows:

***Windows Powershell***

```docker
docker-compose -f docker-compose.db.yml up -d --force-recreate db; sleep 5; docker-compose -f docker-compose.db.yml up flyway; docker-compose -f docker-compose.db.yml down
```

**Linux Shell**

```docker
docker-compose -f docker-compose.db.yml up -d --force-recreate db && sleep 5 && docker-compose -f docker-compose.db.yml up flyway && docker-compose -f docker-compose.db.yml down
```

The sleep command is to allow the database to startup before executing the flyway step.

By simply including the above Shell or Powershell command in your pipeline script, you would be including SQl script testing.

**Note:**

In an Agile Scrum environment such as ours we release to production every 2 weeks. As part of our release cycle we run the above docker-compose commands but only run the final "docker-compose down" command after saving the docker image for the database and publishing it to the docker repository. This new database image represents the latest production image and will be used in the next sprint for testing the SQL scripts.

The same process above can be used for any RDB that has docker images available. You could also create your own database docker images if you were so inclined.

_Happy SQL Script Testing_