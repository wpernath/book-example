# An extended Helm Chart example
In chapter 3 of my book `Getting GitOps. A Practical Platform with OpenShift, Argo CD and Tekton.`, I am discussing the basics of creating and using Helm Charts. I also dig into the the use case of creating a post-install and post-upgrade job. 

However, it really was a basic example which only focused on what’s necessary to create and deploy a Helm Chart. 

This article is showing some more advanced techniques to create a chart which could be installed more than once in the same namespace. It also shows how you could easily install a dependent database.

## The use case
During the development of our `person-service` (see chapter one in the book), we were realizing that we need to have a dependent database installed with our chart. As we have discussed in chapter one, we have three options here:
1. We try to use the corresponding OpenShift Template to install the necessary PostgreSQL database 
2. We use the [CrunchyData Postgres Operator] for the database 
3. We install a dependent Helm Chart with our chart. For example the [PostgreSQL chart by Bitnami] 

Also, we want to make sure that our chart could be installed multiple times on each namespace. 

The sources for this example can be found on [GitHub].

## Making the Chart installable multiple times in the same namespace
The most important step to make sure your chart is installable multiple times in the same namespace is to use generated names for the manifest files. For this there is an object called `Release` with the following parameters:
- `Name`: The name of the release
- `Namespace`: Where are you going to install the chart
- `Revision`: Revision number of this release (1 on install and each update increments it by one)
- `IsInstall`: True if it’s an installation process
- `IsUpgrade`: True if it’s an upgrade process

So if you want to make sure, your chart installation is not conflicting with any other installations in the same namespace, do the following:

apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-config
  labels:
    app.kubernetes.io/part-of: {{ .Release.Name }}-chart
data:
  APP_GREETING: |- 
    {{ .Values.config.greeting | default "Yeah, it's openshift time" }}

This creates a ConfigMap with the name of the release, followed by a dash followed by `config`. Of course, you now need to make sure that the ConfigMap is being read by the Deployment accordingly:

- image: "{{ .Values.deployment.image }}:{{ .Values.deployment.version }}"
          envFrom:
            - configMapRef:
                name: {{ .Release.Name }}-config

[...]

If you are updating all the other manifest files in your Helm’s `templates` folder, you are able to install your chart multiple times. 

$ helm install person-service1 <path to chart>
$ helm install person-service2 <path to chart>


## Installing the database via an existing OpenShift Template
The easiest way of installing a PostgreSQL database in an OpenShift namespace is surely via an OpenShift Template. We have done it already several times during the chapters of the book. The call is simple:

$ oc new-app postgresql-persistent \
	-p POSTGRESQL_USER=wanja \
	-p POSTGRESQL_PASSWORD=wanja \
	-p POSTGRESQL_DATABASE=wanjadb \
	-p DATABASE_SERVICE_NAME=wanjaserver

But how could we automate this process? There is no way to execute this call from within a Helm Chart installation (well, of course there is a way by using a pre-install hook, but this is quite ugly).

Fortunately, the OpenShift client has a function called `process`, which is processing a template. The result of this call is a list of YAML-Objects which can then be installed into OpenShift.

$ oc process postgresql-persistent -n openshift -o yaml

If you’re piping the result into a new file, you would get something like this:

apiVersion: v1
kind: List
items:
- apiVersion: v1
  kind: Secret
  metadata:
    labels:
      template: postgresql-persistent-template
    name: postgresql
  stringData:
    database-name: sampledb
    database-password: KSurRUMyFI2fiVpx
    database-user: user0U4
- apiVersion: v1
  kind: Service
[...]

If you’re not happy with the default parameters for username, password and database name, then call the process function with the `-p PARAM=VALUE` option:

$ oc process postgresql-persistent -n openshift -o yaml \
	-p POSTGRESQL_USER=wanja \
	-p POSTGRESQL_PASSWORD=wanja \
	-p POSTGRESQL_DATABASE=wanjadb \
	-p DATABASE_SERVICE_NAME=wanjaserver

Place the resulting file into your chart’s `templates` folder and it will be used to install the database. If you have a closer look at the file, you can see that it’s using `DATABASE_SERVICE_NAME` as manifest names for its `Service`, `Secret` and `DeploymentConfig` objects, which would make it impossible to install your resulting chart more than once into any namespace. 

If you’re providing the string `-p DATABASE_SERVICE_NAME='pg-{{ .Release.Name }}'` instead of the fixed string `wanjaserver`, then this will be used as object name for the manifest files mentioned above. 

However, if you’re trying to install your Helm Chart now, you’re getting some verification error messages. This is because `oc process` generates some top level status fields, which are not known to the Helm parser. So you need to remove them. 

The only thing you now need to do is to connect your `person-service` Deployment with the corresponding database instance. Simply add the following entries to the `env` section of your `Deployment.yaml` file:

[...]
          env:
            - name: DB_host
              value: pg-{{ .Release.Name }}.{{ .Release.Namespace }}.svc
            - name: DB_dbname
              valueFrom:
                secretKeyRef:
                  name: pg-{{ .Release.Name }}
                  key: database-name
            - name: DB_user
              valueFrom:
                secretKeyRef:
                  name: pg-{{ .Release.Name }}
                  key: database-user
            - name: DB_password
              valueFrom:
                secretKeyRef:
                  name: pg-{{ .Release.Name }}
                  key: database-password
[...]

Then your Helm Chart is ready to be packaged and installed:

$ helm package better-helm/with-templ
$ helm upgrade --install ps1 person-service-templ-0.0.10.tgz

Unfortunately, one of the resulting manifest files is a `DeploymentConfig`, which is OpenShift only. So this chart can not be installed on any other Kubernetes distribution. So let’s discuss other options.

## Installing a Kubernetes Operator with your chart
Another possibility of installing a dependent database with your Helm Chart is to look for a Kubernetes Operator on [OperatorHub]. If your cluster already has an OperatorLifecycleManager (OLM) installed (for example all OpenShift clusters do have one installed) then the only thing you need to do is creating a Subscription which describes your desire to install an Operator. 

For example, to install the community operator by CrunchyData into OpenShift, you need to create the following file:

apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: postgresql-operator
  namespace: openshift-operators
spec:
  channel: v5 
  name: postgresql
  source: community-operators 
  sourceNamespace: openshift-marketplace

If you’re putting this file into the folder `crds` of your Helm Chart, Helm takes care of installing the operator before it’s processing the template files of the chart. But please note, Helm will **never** uninstall the CRDs. So the operator will stay on the Kubernetes cluster.

If you’re placing the following file into the `templates` folder of the chart, you get your PostgreSQL database instance ready to be used:

apiVersion: postgres-operator.crunchydata.com/v1beta1
kind: PostgresCluster
metadata:
  name: {{ .Release.Name }}-db
  labels:
    app.kubernetes.io/part-of: {{ .Release.Name }}-chart
spec:
  image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres:centos8-13.5-0
  postgresVersion: 13
  instances:
    - name: instance1
      dataVolumeClaimSpec:
        accessModes:
        - "ReadWriteOnce"
        resources:
          requests:
            storage: 1Gi
  backups:
    pgbackrest:
      image: registry.developers.crunchydata.com/crunchydata/crunchy-pgbackrest:centos8-2.36-0
      repos:
      - name: repo1
        volume:
          volumeClaimSpec:
            accessModes:
            - "ReadWriteOnce"
            resources:
              requests:
                storage: 1Gi

Of course you now need to make sure, your `person-service` is able to connect to this PostgreSQL instance. Simply add a `secretRef` to the Deployment file with the following content:

[...]
          envFrom:
            - secretRef:
                name: {{ .Release.Name }}-db-pguser-{{ .Release.Name }}-db
              prefix: DB_
[...]

This will map all values of the PostgresCluster secret to your deployment with a prefix of `DB_`, which are exactly those we need.

Now your chart is ready to be packaged and can be installed in any namespace of OpenShift:

$ helm package with-crds
$ helm install ps1 person-service-crd-0.0.10.tgz
$ helm uninstall ps1


## Installing the database by adding a sub chart dependency
