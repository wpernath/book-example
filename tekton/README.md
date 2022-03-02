# Getting GitOps. 
## Tekton sample
This example is about Tekton / OpenShift Pipelines and is being discussed in chapter 4 of the book. Please also have a look at the script `pipeline.sh`. It installs all the necessary Tasks and resources if you call it with the `init` parameter:

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
