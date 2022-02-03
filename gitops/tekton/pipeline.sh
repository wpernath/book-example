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
CONTEXT_DIR=person-service
IMAGE_NAME=quay.io/wpernath/person-service
IMAGE_USER=wpernath
IMAGE_PASSWORD=
TARGET_NAMESPACE=book-ci
FORCE_SETUP="false"

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
      pipeline.sh init [--force] --git-user <user> --git-password <pwd> --registry-user <user> --registry-password
      pipeline.sh build -u wpernath -p <nope> [-t <target-namespace>]
      pipeline.sh stage -r v1.2.5 [-g <config-git-rep>] [-i <target-image>] [-t <target-namespace>]
      pipeline.sh logs [-t <target-namespace]
  
  COMMANDS:
      init                           creates ConfigMap, Secrets, Tasks and Pipelines into $TARGET_NAMESPACE
      build                          starts the dev-pipeline in $TARGET_NAMESPACE
      stage                          starts the stage-pipeline in $TARGET_NAMESPACE
      logs                           shows logs of the last pipeline run in $TARGET_NAMESPACE
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
      -f, --force                   By default, this script assumes, you've created demo-setup/setup.yaml
                                    if you haven't, use this flag to force the setup of the summit-cicd NS
EOF
}

while (( "$#" )); do
  case "$1" in
    build|stage|logs|init)
      COMMAND=$1
      shift
      ;;
    -f|--force)
      FORCE_SETUP="true"
      shift 1
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

echo "Using parameters:"
echo "   GIT_USER    : $GIT_USER"
echo "   GIT_PASSWORD: $GIT_PASSWORD"
echo "   REG_USER    : $IMAGE_USER"
echo "   REG_PASSWORD: $IMAGE_PASSWORD"
echo "   FORCE_SETUP : $FORCE_SETUP "

  # prepare secrets for SA
  if [ -z $GIT_USER ]; then 
    command.help
    err "You have to provide credentials via --git-user"
  fi

  if [ -z $GIT_PASSWORD ]; then 
    command.help
    err "You have to provide credentials via --git-password"
  fi

  if [ -z $IMAGE_USER ]; then 
    command.help
    err "You have to provide credentials via --registry-user"
  fi

  if [ -z $IMAGE_PASSWORD ]; then 
    command.help
    err "You have to provide credentials via --registry-password"
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

  # apply all tekton related setup
  if [[ "$FORCE_SETUP" == "true" ]]; then
    info "Creating demo setup by calling $SCRIPT_DIR/kustomization.yaml"
    oc apply -k "$SCRIPT_DIR" -n $TARGET_NAMESPACE

    while :; do
      oc get ns/book-ci > /dev/null && break
      sleep 2
    done
  fi

  oc apply -f /tmp/secret.yaml -n $TARGET_NAMESPACE
}


command.logs() {
    tkn pr logs -f -L -n $TARGET_NAMESPACE
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

    oc apply -f /tmp/stage-pr.yaml -n $TARGET_NAMESPACE
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

    oc apply -f /tmp/pipelinerun.yaml -n $TARGET_NAMESPACE
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
