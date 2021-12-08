#!/bin/bash
# This starts the pipeline new-pipeline with a given 

set -e -u -o pipefail
declare -r SCRIPT_DIR=$(cd -P $(dirname $0) && pwd)
declare COMMAND="help"

GIT_URL=https://github.com/wpernath/person-service-config.git
GIT_REVISION=main
GIT_USER=""
GIT_PASSWORD=""

PIPELINE=dev-pipeline
CONTEXT_DIR=the-source
IMAGE_NAME=quay.io/wpernath/person-service
IMAGE_USER=wpernath
IMAGE_PASSWORD=
TARGET_NAMESPACE=book-dev

valid_command() {
  local fn=$1; shift
  [[ $(type -t "$fn") == "function" ]]
}

info() {
    printf "\n# INFO: $@\n"
}

err() {
  printf "\n# ERROR: $1\n"
  exit 1
}

command.help() {
  cat <<-EOF
  Starts a new pipeline in current kubernetes context

  Usage:
      pipeline.sh [command] [options]
  
  Examples:
      pipeline.sh init --git-user <user> --git-password <pwd> --registry-user <user> --registry-password
      pipeline.sh build -u wpernath -p <nope> 
      pipeline.sh stage -r v1.2.5 -g <config-git-rep> -i <target-image>
      pipeline.sh logs
  
  COMMANDS:
      init                           creates ConfigMap, Tasks and Pipelines into current context
      build                          starts the dev-pipeline
      stage                          starts the stage-pipeline
      logs                           shows logs of the last pipeline run
      help                           Help about this command

  OPTIONS:
      -u, --registry-user           User to store the image into quay.io ($IMAGE_USER)
      -p, --registry-password       Password to store the image into quay.io ($IMAGE_PASSWORD)
      --git-user                    User to read/write into github
      --git-password                Password to read/write into github
      -i, --target-image            Target image name to push to ($IMAGE_NAME)
      -c, --context-dir             Which context-dir to user ($CONTEXT_DIR)
      -t, --target-namespace        Which target namespace to start the app ($TARGET_NAMESPACE)
      -g, --git-repo                Which quarkus repository to clone ($GIT_URL)
      -r, --git-revision            Which git revision to use ($GIT_REVISION)

EOF
}

while (( "$#" )); do
  case "$1" in
    build|stage|logs|init)
      COMMAND=$1
      shift
      ;;
    -c|--context-dir)
      CONTEXT_DIR=$2
      shift 2
      ;;
    -i|--target-image)
      IMAGE_NAME=$2
      shift 2
      ;;
    -t|--target-namespace)
      TARGET_NAMESPACE=$2
      shift 2
      ;;
    -u|--registry-user)
      IMAGE_USER=$2
      shift 2
      ;;
    -p|--registry-password)
      IMAGE_PASSWORD=$2
      shift 2
      ;;
    --git-user)
      GIT_USER=$2
      shift 2
      ;;
    --git-password)
      GIT_PASSWORD=$2
      shift 2
      ;;
    -g|--git-repo)
      GIT_URL=$2
      shift 2
      ;;
    -r|--git-revision)
      GIT_REVISION=$2
      shift 2
      ;;
    -l|--pipeline)
      PIPELINE=$2
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*|--*)
      command.help
      err "Error: Unsupported flag $1"
      ;;
    *) 
      break
  esac
done


command.init() {
  # This script imports the necessary files into the current project 
  pwd

  # prepare secrets for SA
  if [ $GIT_USER = "" ]; then
    command.help
    err "You have to provide GIT credentials via --git-user and --git-password"
  fi

  cat > /tmp/secret.yaml <<-EOF
apiVersion: v1
kind: Secret
metadata:
  name: git-user-pass
  annotations:
    tekton.dev/git-0: https://github.com # Described below
type: kubernetes.io/basic-auth
stringData:
  username: $GIT_USER
  password: $GIT_PASSWORD
---
apiVersion: v1
kind: Secret
metadata:
  annotations:
    tekton.dev/docker-0: https://quay.io
  name: quay-push-secret
type: kubernetes.io/basic-auth
stringData:
  username: $IMAGE_USER
  password: $IMAGE_PASSWORD
EOF

  oc apply -f /tmp/secret.yaml

  # apply all tekton related
  oc apply -k .
}


command.logs() {
    tkn pr logs -f -L
}

command.stage() {
  cat > /tmp/stage-pr.yaml <<-EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: stage-pipeline-run-$(date "+%Y%m%d-%H%M%S")
spec:
  params:
    - name: release-name
      value: $GIT_REVISION
  workspaces:
    - name: shared-workspace
      persistentVolumeClaim:
        claimName: builder-pvc
  pipelineRef:
    name: stage-pipeline
  serviceAccountName: pipeline-bot
EOF

    oc apply -f /tmp/stage-pr.yaml
}

command.build() {
  cat > /tmp/pipelinerun.yaml <<-EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: $PIPELINE-run-$(date "+%Y%m%d-%H%M%S")
spec:
  params:
    - name: repo-password
      value: $IMAGE_PASSWORD
  workspaces:
    - name: source
      persistentVolumeClaim:
        claimName: builder-pvc
    - configMap:
        name: maven-settings
      name: maven-settings
  pipelineRef:
    name: dev-pipeline
  serviceAccountName: pipeline-bot
EOF

    oc apply -f /tmp/pipelinerun.yaml
}

main() {
  local fn="command.$COMMAND"
  valid_command "$fn" || {
    command.help
    err "invalid command '$COMMAND'"
  }

  cd $SCRIPT_DIR
  $fn
  return $?
}

main
