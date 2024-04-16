#!/bin/bash

set -eu

echo "GOLANG_VERSION passed in is: ${GOLANG_VERSION}"
echo "This is the installed go version: $(go version)"
echo "This is the installed cf cli version: $(cf -v)"

echo "ACCEPTANCE_TESTS_VERSION is ${ACCEPTANCE_TESTS_VERSION}"



# Get the tarball with the test
wget -O app-autoscaler-acceptance-tests.tgz  https://github.com/cloudfoundry/app-autoscaler-release/releases/download/v${ACCEPTANCE_TESTS_VERSION}/app-autoscaler-acceptance-tests-v${ACCEPTANCE_TESTS_VERSION}.tgz
tar -xvzf app-autoscaler-acceptance-tests.tgz 

cd acceptance
ls -alh

cat > integration_config.json <<EOF
{
  "api": "${CF_API}",
  "admin_user": "${CF_ADMIN_USER}",
  "admin_password": "${CF_ADMIN_PASSWORD}",
  "apps_domain": "${CF_APPS_DOMAIN}",
  "skip_ssl_validation": true,
  "use_http": false,

  "service_name": "app-autoscaler",
  "service_plan": "autoscaler-free-plan",
  "aggregate_interval": 120,
  "health_endpoints_basic_auth_enabled": true,

  "autoscaler_api": "{AUTOSCALER_API}",
  "service_offering_enabled": true
}
EOF
export CONFIG=$PWD/integration_config.json


echo "~FIN~"