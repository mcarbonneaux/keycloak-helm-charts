## Database and Image Configuration

### Keycloak Image Tags

It is strongly recommended to use immutable tags (e.g., `26.1.1`) rather than rolling tags (e.g., `latest` or `26`) in a production environment. This ensures that your deployment remains consistent and does not change automatically if the same tag is updated with a new image build.

Official Keycloak images are available on [Quay.io](https://quay.io/repository/keycloak/keycloak).

### Database configuration

This chart requires an external PostgreSQL database. You must specify the credentials for the database using the `db*` parameters. Here is an example:

```yaml
dbHost: myexternalhost
dbPort: 5432
dbUser: keycloak
dbPassword: mypassword
dbDatabase: keycloak
dbSchema: public
```

> NOTE: Only PostgreSQL database server is supported as database backend by default with these parameters.

It is possible to run Keycloak with an external MSSQL database with the following settings:

```yaml
dbHost: "mssql.example.com"
dbPort: 1433
dbUser: keycloak
dbDatabase: keycloak
dbExistingSecret: passwords
extraEnvVars:
  - name: KC_DB # override values from the conf file
    value: 'mssql'
  - name: KC_DB_URL
    value: 'jdbc:sqlserver://mssql.example.com:1433;databaseName=keycloak;'
```

