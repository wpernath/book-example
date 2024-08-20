# Using the Examples discussed in the book *Getting GitOps.*

You can download the final eBook as PDF here:

https://developers.redhat.com/e-books/getting-gitops-practical-platform-openshift-argo-cd-and-tekton

## Prerequisites
In order to run all of the examples I am discussing in this book, you should have the following software available

- OpenShift 4.8.x (see below for instructions)
- Quarkus 2.16.x
- Maven 3.8.3
- Java JDK 11 or better
- git
- Docker Desktop or Podman Desktop
- OpenShift client (`oc`) matching the version of the OpenShift Cluster
- An Editor to work with (VScode, Eclipse, IntelliJ)

OpenShift needs to have the following Operators installed:
- OpenShift GitOps
- OpenShift Pipelines
- Crunchy Postgres for Kubernetes by Crunchy Data

## A quick Note on Quarkus Versions
If you want to use latest Quarkus versions, please make sure to install the matching requirements for that version of Quarkus. Have a look at the following [guide](https://quarkus.io/guides/getting-started)

## Getting an OpenShift instance
You have three possible options to get an OpenShift installation

### Using Red Hat Developer Sandbox
This solution is the easiest one but unfortunately very limited. You can’t create new projects (namespaces) and you’re not allowed to install additional operators. This solution is only meant to be used for chapters one and two and the helm chart part of chapter three. 

Go to the [Developer Sandbox][1] and register for free. 

### Using CodeReady Containers (`crc`)
CodeReady Containers (`crc`) provides a single node OpenShift installation for Windows, macOS and Linux. It runs OpenShift on an embedded virtual machine. You have all the flexibility of an external OpenShift cluster without the need of 3 or more master nodes. You are also able to install additional Operators. 

This solution requires the following resources on your local machine:
- 9 GB free memory 
- 4 CPU cores
- 50 GB free hard disk space

Go to [GitHub][2] for a list of releases and have a look at the [official documentation][3]. 


### Using Single Node OpenShift (`SNO`)
With this solution you have most flexibility in using your OpenShift installation. But of course this also requires most resources. You should have a dedicated spare machine with the following specs in order to use `SNO`:
- 8 vCPU cores
- 32GB free memory
- 150GB free hard disk space

Have a look at the [Red Hat Console][4] to start the installation process. After installation you should have a look at my [OpenShift Config script][5], you can find on GitHub as well. This script creates persistent volumes, makes the internal registry non-ephemeral, creates a cluster-admin user and installs necessary operators and a CI environment with Nexus (a maven repository) and Gogs (a Git repository). 

## The container image registry
I am using [Quay.io][6] for all of my images. The account is for free and it does not limit upload/download rates. Once registered, go to `Account Settings` —\> `User Settings` and generate an encrypted password. Quay.io will give you some options to store your password hash, for example as a Kubernetes-secret, which you can then directly use as push-/pull secrets. 

The free account however limits you to only create public repositories, so anybody can read from your repository but only you are allowed to write and update your image. 

Once you’ve created your image in the repository, you have to go to the image properties and make sure it’s public. By default, Quay.io creates private repositories. 

However, you can use any docker compliant registry to store your container images on. 

## The structure of the example
All the examples can be found on GitHub: [https://github.com/wpernath/book-example][7]

Please fork it and then use it as you want to use it. 

### Chapter One: Folders
The folder `person-service` contains the Java sources of the Quarkus example. If you want to deploy it on OpenShift, please make sure to first install a PostgreSQL server, either via Crunchy Data or by instantiating the template `postgresql-persistent`. 

```bash
$ oc new-app postgresql-persistent \
	-p POSTGRESQL_USER=wanja \
	-p POSTGRESQL_PASSWORD=wanja \
	-p POSTGRESQL_DATABASE=wanjadb \
	-p DATABASE_SERVICE_NAME=wanjaserver
```

### Chapter Two: Folders
- `raw-kubernetes` contains the raw Kubernetes manifest files 
- `ocp-template` contains the OpenShift Template file
- `kustomize`contains a set of basic files for use with Kustomize
- `kustomize-ext` contains a set of advanced files for use with Kustomize 

### Chapter Three: Folders
This chapter is about Helm Charts and Kubernetes Operators. So you can find the corresponding folders are `helm-chart` and `kube-operator`.

### Chapter Four: Folders
This chapter is about Tekton / OpenShift Pipelines. The sources can be found in   the folder `tekton`. Please also have a look at the script `pipeline.sh`. It installs all the necessary Tasks and resources if you call it with the `init` parameter:

```bash
$ pipeline.sh init
configmap/maven-settings configured
persistentvolumeclaim/maven-repo-pvc configured
persistentvolumeclaim/builder-pvc configured
task.tekton.dev/kustomize configured
task.tekton.dev/maven-caching configured
pipeline.tekton.dev/build-and-push-image configured
```

You can start the pipeline by executing
```bash
$ pipeline.sh start -u wpernath -p <your-quay-token>
pipelinerun.tekton.dev/build-and-push-image-run-20211125-163308 created
```

### Chapter Five: Folders
This chapter is about using Tekton and ArgoCD. The sources can be found in the folder `gitops`. 

To initialize call:
```bash
$ ./pipeline.sh init [--force] --git-user <user> \
	--git-password <pwd> \
	--registry-user <user> \
	--registry-password <pwd> 
```

This call (if given the `--force` flag) will create the following namespaces and ArgoCD applications for you:
- `book-ci`: Pipelines, Tasks and a Nexus instance 
- `book-dev`: The current dev stage
- `book-stage`: The last stage release

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

[1]:	https://developers.redhat.com/developer-sandbox
[2]:	https://github.com/code-ready/crc/releases
[3]:	https://access.redhat.com/documentation/en-us/red_hat_codeready_containers/1.33/html-single/getting_started_guide/index
[4]:	https://console.redhat.com/openshift/assisted-installer/clusters/~new
[5]:	https://github.com/wpernath/openshift-config
[6]:	https://quay.io/
[7]:	https://github.com/wpernath/book-example
