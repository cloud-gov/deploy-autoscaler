#!/bin/bash

set -eu

#CF_API_URL=$(echo "${CF_API_URL}" | sed 's/\/$//')

echo "GOLANG_VERSION passed in is: ${GOLANG_VERSION}"
echo "This is the installed go version: $(go version)"
echo "This is the installed cf cli version: $(cf -v)"

echo "ACCEPTANCE_TESTS_VERSION is ${ACCEPTANCE_TESTS_VERSION}"



# Get the tarball with the test
wget -O app-autoscaler-acceptance-tests.tgz  https://github.com/cloudfoundry/app-autoscaler-release/releases/download/v${ACCEPTANCE_TESTS_VERSION}/app-autoscaler-acceptance-tests-v${ACCEPTANCE_TESTS_VERSION}.tgz
tar -xvzf app-autoscaler-acceptance-tests.tgz 

cd acceptance
ls -alh



echo "~FIN~"