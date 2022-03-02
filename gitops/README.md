# Getting GitOps. 
## GitOps sample

This is the sample discussed in chapter 5. It's about using Tekton and ArgoCD. 

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
