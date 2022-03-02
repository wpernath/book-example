# Getting GitOps. 
## The source code of the example service

This folder contains the Java sources of the Quarkus example. If you want to deploy it on OpenShift, please make sure to first install a PostgreSQL server, either via Crunchy Data Operator or by instantiating the template `postgresql-persistent`. 

```bash
$ oc new-app postgresql-persistent \
	-p POSTGRESQL_USER=wanja \
	-p POSTGRESQL_PASSWORD=wanja \
	-p POSTGRESQL_DATABASE=wanjadb \
	-p DATABASE_SERVICE_NAME=wanjaserver
```

The complete setup and structure of this example is being discussed in chapter 1 of the book. Please have a look there. 