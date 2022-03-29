# Getting GitOps. 
## GitOps sample

This is the sample discussed in chapter 5. It's about using Tekton and ArgoCD. 

You have to do the following two steps in order to setup the environment. 

## 1. Setup Tekton Pipelines (the CI part)
In order to initialize the Tekton pipelines, call

```bash
$ ./pipeline.sh init --force --git-user <user> \
	--git-password <pwd> \
	--registry-user <user> \
	--registry-password <pwd> 
namespace/book-ci created
serviceaccount/pipeline-bot created
rolebinding.rbac.authorization.k8s.io/book-ci-role-binding created
rolebinding.rbac.authorization.k8s.io/piplinebot-rolebinding1 created
rolebinding.rbac.authorization.k8s.io/piplinebot-rolebinding2 created
configmap/maven-settings created
service/nexus created
persistentvolumeclaim/builder-pvc created
persistentvolumeclaim/nexus-pv created
deployment.apps/nexus created
route.route.openshift.io/nexus created
pipeline.tekton.dev/dev-pipeline created
pipeline.tekton.dev/stage-pipeline created
task.tekton.dev/create-release created
task.tekton.dev/extract-kustomize-digest created
task.tekton.dev/extract-quarkus-digest created
task.tekton.dev/git-update-deployment created
task.tekton.dev/maven-caching created
secret/git-user-pass created
secret/quay-push-secret created
```

This call (if given the `--force` flag) will create the following namespaces and ArgoCD applications for you:
- `book-ci`: Pipelines, Tasks and a Nexus instance 

## 2. Setup ArgoCD Applications (the CD part)

To initialize the ArgoCD part, call the following

```bash
$ oc apply -k book-example/gitops/argocd
namespace/book-dev created
namespace/book-stage created
rolebinding.rbac.authorization.k8s.io/book-dev-role-binding created
rolebinding.rbac.authorization.k8s.io/book-stage-role-binding created
application.argoproj.io/book-dev created
application.argoproj.io/book-stage created
```

This will create two namespaces with all roles properly setup so that Argo CD can then start initializing the environment. It will take a while until you're able to see the `person-service` with a PostgreSQL database instance up and running in those two namespaces.


## Calling the pipelines

In order to call the build pipeline in `book-ci`, call 

```bash
$ ./pipeline.sh build -u <reg-user> \
	-p <reg-password>
```

This starts the development pipeline as discussed in chapter 5. Whenever the pipeline is successfully executed, you should see an updated message on the `person-service-config` Git repository. And you should see that ArgoCD has initiated a synchronization process, which ends with a redeployment of the Quarkus application.

To start the staging pipeline, call
```bash
$ ./pipeline.sh stage -r v1.0.1-testing
```

This creates a new branch in Git called `release-v1.0.1-testing`, uses the current DEV image, tags it on quay.io and updates the `stage` config in git. 

In order to apply the changes, you need to either merge the branch directly or create a pull request and merge the changes then. 
