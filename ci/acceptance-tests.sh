#!/bin/bash

set -eu

echo "This is the installed go version: $(go version)"
echo "This is the installed cf cli version: $(cf -v)"
echo "This is the ACCEPTANCE_TESTS_VERSION version: ${ACCEPTANCE_TESTS_VERSION}"


# Get the tarball with the test
wget -O app-autoscaler-acceptance-tests.tgz  https://github.com/cloudfoundry/app-autoscaler-release/releases/download/v${ACCEPTANCE_TESTS_VERSION}/app-autoscaler-acceptance-tests-v${ACCEPTANCE_TESTS_VERSION}.tgz
tar -xzf app-autoscaler-acceptance-tests.tgz 

cd acceptance

# Set the config file needed for the acceptance tests
echo "Writing config file for acceptance tests to acceptance/integration_config.json, do not ever print this out into concourse logs!"

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

  "autoscaler_api": "${AUTOSCALER_API}",
  "service_offering_enabled": true
}
EOF
export CONFIG=$PWD/integration_config.json

# Set GINKGO_BINARY since its provided in the tarball, omit this to have it built at runtime
export GINKGO_BINARY=$PWD/ginkgo_v2_linux_amd64


# Run the actual test, pick one: {broker, api, app}
./bin/test ${COMPONENT_TO_TEST}

echo "~FIN~"