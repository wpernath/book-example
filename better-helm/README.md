# An extended Helm Chart example
In chapter 3 of my book `Getting GitOps. A Practical Platform with OpenShift, Argo CD and Tekton.`, I am discussing the basics of creating and using Helm Charts. I also dig into the the use case of creating a post-install and post-upgrade job. 

However, it really was a basic example which only focused on what’s necessary to create and deploy a Helm Chart. 

This article is showing some more advanced techniques to create a chart which could be installed more than once in the same namespace. It also shows how you could easily install a dependent database with your chart.

The sources for this example can be found on [GitHub](https://github.com/wpernath/book-example/tree/main/better-helm).

## The use case
During the development of our `person-service` (see chapter one in the book), we were realizing that we need to have a dependent database installed with our chart. As we have discussed in chapter one, we have three options here:
1. We try to use the corresponding OpenShift Template to install the necessary PostgreSQL database 
2. We use the [CrunchyData Postgres Operator](https://github.com/CrunchyData/postgres-operator/) (or any other Operator defined PostgreSQL database extension) for the database 
3. We install a dependent Helm chart with our chart. For example the [PostgreSQL chart by Bitnami](https://artifacthub.io/packages/helm/bitnami/postgresql) 

Also, we want to make sure that our chart could be installed multiple times on each namespace.

## Making the Chart installable multiple times in the same namespace
The most important step to make sure your chart is installable multiple times in the same namespace is to use generated names for all the manifest files. Therefore there is an object called `Release` with the following properties:
- `Name`: The name of the release
- `Namespace`: Where are you going to install the chart
- `Revision`: Revision number of this release (1 on install and each update increments it by one)
- `IsInstall`: True if it’s an installation process
- `IsUpgrade`: True if it’s an upgrade process

So if you want to make sure, your chart installation is not conflicting with any other installations in the same namespace, do the following:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-config
  labels:
    app.kubernetes.io/part-of: {{ .Release.Name }}-chart
data:
  APP_GREETING: |- 
    {{ .Values.config.greeting | default "Yeah, it's openshift time" }}
```

This creates a ConfigMap with the name of the release, followed by a dash followed by `config`. Of course, you now need to make sure that the ConfigMap is being read by the Deployment accordingly:

```yaml
- image: "{{ .Values.deployment.image }}:{{ .Values.deployment.version }}"
          envFrom:
            - configMapRef:
                name: {{ .Release.Name }}-config

[...]
```

If you are updating all the other manifest files in your Helm’s `templates` folder, you are able to install your chart multiple times. 

```bash
$ helm install person-service1 <path to chart>
$ helm install person-service2 <path to chart>
```


## Installing the database via an existing OpenShift Template
The easiest way of installing a PostgreSQL database in an OpenShift namespace is surely via an OpenShift Template. We have done it already several times during the chapters of the book. The call is simple:

```bash
$ oc new-app postgresql-persistent \
	-p POSTGRESQL_USER=wanja \
	-p POSTGRESQL_PASSWORD=wanja \
	-p POSTGRESQL_DATABASE=wanjadb \
	-p DATABASE_SERVICE_NAME=wanjaserver
```

But how could we automate this process? There is no way to execute this call from within a Helm Chart installation (well, of course there is a way by using a pre-install hook, but this is quite ugly).

Fortunately, the OpenShift client has a function called `process`, which is processing a template. The result of this call is a list of YAML-Objects which can then be installed into OpenShift.

```bash
$ oc process postgresql-persistent -n openshift -o yaml
```

If you’re piping the result into a new file, you would get something like this:

```yaml
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
```

If you’re not happy with the default parameters for username, password and database name, then call the process function with the `-p PARAM=VALUE` option:

```bash
$ oc process postgresql-persistent -n openshift -o yaml \
	-p POSTGRESQL_USER=wanja \
	-p POSTGRESQL_PASSWORD=wanja \
	-p POSTGRESQL_DATABASE=wanjadb \
	-p DATABASE_SERVICE_NAME=wanjaserver
```

Place the resulting file into your chart’s `templates` folder and it will be used to install the database. If you have a closer look at the file, you can see that it’s using `DATABASE_SERVICE_NAME` as manifest names for its `Service`, `Secret` and `DeploymentConfig` objects, which would make it impossible to install your resulting chart more than once into any namespace. 

If you’re providing the string `-p DATABASE_SERVICE_NAME='pg-{{ .Release.Name }}'` instead of the fixed string `wanjaserver`, then this will be used as object name for the manifest files mentioned above. 

However, if you’re trying to install your Helm Chart now, you’re getting some verification error messages. This is because `oc process` generates some top level status fields, which are not known to the Helm parser. So you need to remove them. 

The only thing you now need to do is to connect your `person-service` Deployment with the corresponding database instance. Simply add the following entries to the `env` section of your `Deployment.yaml` file:

```yaml
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
```

Then your Helm Chart is ready to be packaged and installed:

```bash
$ helm package better-helm/with-templ
$ helm upgrade --install ps1 person-service-templ-0.0.10.tgz
```

Unfortunately, one of the resulting manifest files is a `DeploymentConfig`, which is OpenShift only. So this chart can not be installed on any other Kubernetes distribution. So let’s discuss other options.

## Installing a Kubernetes Operator with your chart
Another possibility of installing a dependent database with your Helm Chart is to look for a Kubernetes Operator on [OperatorHub](https://operatorhub.io/). If your cluster already has an OperatorLifecycleManager (OLM) installed (for example all OpenShift clusters do have one installed) then the only thing you need to do is creating a Subscription which describes your desire to install an Operator. 

For example, to install the community operator by CrunchyData into OpenShift, you need to create the following file:

```yaml
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
```

If you’re putting this file into the folder `crds` of your Helm Chart, Helm takes care of installing the operator before it’s processing the template files of the chart. But please note, Helm will **never** uninstall the CRDs. So the operator will stay on the Kubernetes cluster.

If you’re placing the following file into the `templates` folder of the chart, you get your PostgreSQL database instance ready to be used:

```yaml
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
```

Of course you now need to make sure, your `person-service` is able to connect to this PostgreSQL instance. Simply add a `secretRef` to the Deployment file with the following content:

```yaml
[...]
          envFrom:
            - secretRef:
                name: {{ .Release.Name }}-db-pguser-{{ .Release.Name }}-db
              prefix: DB_
[...]
```

This will map all values of the PostgresCluster secret to your deployment with a prefix of `DB_`, which are exactly those you need.

Now your chart is ready to be packaged and can be installed in any namespace of OpenShift:

```bash
$ helm package with-crds
$ helm install ps1 person-service-crd-0.0.10.tgz
$ helm uninstall ps1
```


## Installing the database by adding a sub chart dependency
The last option is to use a sub chart within your chart. For this scenario, Helm has a [dependency management system](https://helm.sh/docs/topics/charts/#chart-dependencies) which makes it easier for you as a chart developer to use third-party charts.

This example is using the [Bitnami PostgreSQL chart](https://artifacthub.io/packages/helm/bitnami/postgresql), which you can find on [ArtifactHub](https://artifacthub.io). 

First of all, you have to change the `Chart.yaml` file to add the external dependency. With the following lines you are adding the dependency to the PostgreSQL database of Bitnami with the version `11.1.3`. 

```yaml
dependencies:
    - name: postgresql
      repository: https://charts.bitnami.com/bitnami
      version: 11.1.3
```

If you want to define properties from within your `values.yaml` file, you simply need to use the name of the chart as the first parameter in the tree, in this case it is `postgresql`. Then you are able to add all necessary parameters below that key:

```yaml
postgresql:
  auth:
    username: wanja
[...]
```
Then you need to have a look at the documentation of the Bitnami chart to understand how you’re able to use it in your target environment (which is OpenShift in this case). 

Unfortunately, the current documentation is a bit outdated (as of time of this writing), so you would not be able to install your chart without further digging into their own `values.yaml` file to see which security settings you have to set in order to use it in OpenShift and its strong enterprise security concept. 

Find here a minimum list of settings:
```yaml
postgresql:
    auth:
        username: wanja
        password: wanja
        database: wanjadb
    primary:
        podSecurityContext:
            enabled: false
            fsGroup: ""
        containerSecurityContext:
            enabled: false
            runAsUser: "auto"

    readReplicas:
        podSecurityContext:
            enabled: false
            fsGroup: ""
        containerSecurityContext:
            enabled: false
            runAsUser: "auto"

    volumePermissions:
        enabled: false
        securityContext:
            runAsUser: "auto"

```

The final step is again to make sure, your Deployment is able to connect to this database. 

```yaml
[...]
          env:
            - name: DB_user
              value: wanja
            - name: DB_password
              valueFrom:
                secretKeyRef:
                  name: {{ .Release.Name }}-postgresql
                  key: password
            - name: DB_dbname
              value: wanjadb
            - name: DB_host            
              value: {{ .Release.Name }}-postgresql.{{ .Release.Namespace }}.svc
[...]
```

Now you need to package your chart. Note, that because you’re depending on a third-party chart, you need to use the `-u` option, which is downloading the dependencies into the `charts` folder of your Helm chart.

```bash
$ helm package -u better-helm/with-subchart
$ helm install ps1 person-service-sub.0.0.11.tgz
```

## Summary
Using Helm charts for your own projects is quite easy, even if you need to make sure certain dependencies are being installed as well. Thanks to the Helm dependency management, you’re able to easily use sub charts with your charts. And thanks to the flexibility of Helm, you’re also even able to either use a (processed) template or to quickly install a Kubernetes Operator before you’re proceeding. 

