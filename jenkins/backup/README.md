# Local database backup pipeline

`jenkins/backup/Jenkinsfile` backs up an Azure SQL (MSSQL) database and an
Azure Database for PostgreSQL database to a **local directory on the Jenkins
agent**. Nothing is uploaded to Azure Blob Storage.

The tutorial build pipeline in `jenkins/Jenkinsfile` is unaffected.

## Agent prerequisites

The agent must be labelled `azure-backup` and have:

| Tool | Used for |
| --- | --- |
| [`sqlpackage`](https://learn.microsoft.com/sql/tools/sqlpackage/sqlpackage-download) | Exporting Azure SQL to `.bacpac` (Azure SQL does not allow `BACKUP DATABASE`) |
| `pg_dump` / `pg_restore` | Dumping PostgreSQL, version >= the server version |

The agent also needs enough free disk space under `BACKUP_ROOT` for the dumps,
and its outbound IP must be allowed by the firewall rules of both database
servers.

## Credentials

Create these in Jenkins (**Manage Jenkins → Credentials**) — never put secrets
in this repository:

| Credential ID | Kind | Contents |
| --- | --- | --- |
| `azure-mssql-backup-login` | Username with password | Azure SQL login / password |
| `azure-postgres-backup-login` | Username with password | PostgreSQL login / password |

For PostgreSQL Single Server the username is `user@servername`; for Flexible
Server it is just `user`. The PostgreSQL password is passed through
`PGPASSWORD` rather than on the command line.

## Parameters

| Parameter | Default | Meaning |
| --- | --- | --- |
| `BACKUP_MSSQL` | `true` | Run the MSSQL export |
| `BACKUP_POSTGRES` | `true` | Run the PostgreSQL dump |
| `BACKUP_ROOT` | `/var/backups/databases` | Local directory holding all backups |
| `RETENTION_DAYS` | `14` | Delete local backups older than this; `0` disables cleanup |
| `MSSQL_SERVER` / `MSSQL_DATABASE` | – | Azure SQL server FQDN and database |
| `PG_HOST` / `PG_DATABASE` | – | PostgreSQL server FQDN and database |

## Layout on disk

```
<BACKUP_ROOT>/<timestamp>-<build number>/
    mssql-<database>-<timestamp>.bacpac
    postgres-<database>-<timestamp>.dump
```

The pipeline runs nightly (`cron('H 2 * * *')`) and can also be started
manually with different parameters.

## Restoring

PostgreSQL:

```sh
pg_restore --host=<host> --username=<user> --dbname=<target-db> \
    --clean --if-exists postgres-<database>-<timestamp>.dump
```

MSSQL:

```sh
sqlpackage /Action:Import \
    /SourceFile:mssql-<database>-<timestamp>.bacpac \
    /TargetServerName:<server> /TargetDatabaseName:<target-db> \
    /TargetUser:<user> /TargetPassword:<password>
```

Restore into a throwaway database periodically — an unverified backup is not a
backup.

## Notes

* A `.bacpac` export of a live Azure SQL database is **not** transactionally
  consistent. For a consistent backup, `CREATE DATABASE ... AS COPY OF ...`
  first, export the copy, then drop it.
* Backup files contain production data. Keep `BACKUP_ROOT` outside the Jenkins
  workspace, restrict its permissions, and do not archive dumps as build
  artifacts.
* Adding off-box storage (such as Azure Blob Storage) later only requires a
  new upload stage; the dump stages stay as they are.
