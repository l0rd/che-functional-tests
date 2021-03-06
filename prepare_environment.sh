#!/bin/bash
set -x
set -e

# We need to disable selinux for now
/usr/sbin/setenforce 0

# Get all the deps in
yum -y install \
  docker \
  make \
  git
service docker start

# Fetch PR and rebase on master, if job runs from PR
cat jenkins-env \
    | grep -E "(ghprbSourceBranch|ghprbPullId)=" \
    | sed 's/^/export /g' \
    > /tmp/jenkins-env
source /tmp/jenkins-env
if [[ ! -z "${ghprbPullId}" ]] && [[ ! -z "${ghprbSourceBranch}" ]]; then
  echo 'Checking out to Github PR branch'
  git fetch origin pull/${ghprbPullId}/head:${ghprbSourceBranch}
  git checkout ${ghprbSourceBranch}
  git fetch origin master
  git rebase FETCH_HEAD
else
  echo 'Working on current branch of EE tests repo'
fi

# Set credentials
set +x
cat jenkins-env \
    | grep -E "(OSIO|KEYCLOAK)" \
    | sed 's/^/export /g' \
    > credential_file
source credential_file
if [[ -z "${OSIO_USERNAME}" ]]; then
  empty_credentials="OSIO username is empty, "
fi 
if [[ -z "${OSIO_PASSWORD}" ]]; then
  empty_credentials=${empty_credentials}"OSIO password is empty, "
fi
if [[ -z "${KEYCLOAK_TOKEN}" ]]; then
  empty_credentials=${empty_credentials}"Keycloak token is empty"
fi
if [[ ! -z "${empty_credentials}" ]]; then
  echo ${empty_credentials}
  exit 1
else
  echo 'OpenShift username and password and Keycloak token are not empty.'
fi
if [[ $(curl -X GET -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" https://sso.openshift.io/auth/realms/fabric8/broker/openshift-v3/token \
   |  grep access_token | wc -l) -ne 1 ]]; then
  echo "Keycloak token is expired"
  exit 1
else
  echo "Keycloak token is alive. Proceeding with EE tests."
fi
echo 'export OSIO_USERNAME='${OSIO_USERNAME} >> ./env-vars
echo 'export OSIO_PASSWORD='${OSIO_PASSWORD} >> ./env-vars
echo 'export KEYCLOAK_TOKEN='${KEYCLOAK_TOKEN} >> ./env-vars
set -x
