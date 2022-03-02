# Getting GitOps.
## Extended Helm Chart sample
This is an extended helm chart sample, which installs the person-service created in chapter 1 with the required database, which will be installed via PGO, the PostgreSQL Operator from CrunchyData. This chart has a few advantages over the original chart:

- It can be installed multiple times in the same namespace 
- It shows how to handle the case where you need to install a Kubernetes Operator with your chart
- The post-install and post-upgrade hook is filling the database with data by calling the person service 

## Installing the chart multiple times in the same namespace
If you're installing a helm chart, you're calling 

```bash
$ helm install <release-name> <chart-name>
```
This is to give each installation a unique name. A release name. If you use the `<release-name>` as `metadata/name` in your manifest definitions, you can easily install this chart more than once in a given namespace. Just use the global Helm variable `{{ .Release.Name }}` to achieve this:

```YAML
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



## Installing the Operator 
Helm provides the feature to install Custom Resource Definitions (CRDs) with your chart. Just create a folder called `crds` within your chart structure and place the corresponding YAML file in there to let Helm do all the rest.

Just be aware that typical Day-1 operations are not applied with CRDs. If you are uninstalling the chart, the CRDs placed in `crds` won't get uninstalled. 

To install Kubernetes Operators via basic YAML-files, you have to create a `Subscription`:

```YAML
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
