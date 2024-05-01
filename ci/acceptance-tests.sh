#!/bin/bash

set -eu
echo "######################################################################"
echo "This is the installed go version: $(go version)"
echo "This is the installed cf cli version: $(cf -v)"
echo "This is the ACCEPTANCE_TESTS_VERSION version: ${ACCEPTANCE_TESTS_VERSION}"
echo "######################################################################"

# Get the tarball with the test
wget -O app-autoscaler-acceptance-tests.tgz  https://github.com/cloudfoundry/app-autoscaler-release/releases/download/v${ACCEPTANCE_TESTS_VERSION}/app-autoscaler-acceptance-tests-v${ACCEPTANCE_TESTS_VERSION}.tgz
tar -xzf app-autoscaler-acceptance-tests.tgz 

cd acceptance

if [ "$COMPONENT_TO_TEST" = "app"] then 


  echo "######################################################################"
  echo "Removing test for cpuutil for v12.2.2"
  echo "######################################################################"

  head -n 257 app/dynamic_policy_test.go > dynamic_policy_test.go
  tail -n +290 app/dynamic_policy_test.go >> dynamic_policy_test.go
  chmod 644 dynamic_policy_test.go
  
  mv app/dynamic_policy_test.go app/dynamic_policy_test.orig.off
  mv dynamic_policy_test.go app/dynamic_policy_test.go


  echo "######################################################################"
  echo "Logging in and create a test org/space, IMPORTANT: bind the public_networks_egress ASG"
  echo "######################################################################"
  cf login -a ${CF_API} -u ${CF_ADMIN_USER} -p "${CF_ADMIN_PASSWORD}" -o cloud-gov -s services
  cf create-org ${AUTOSCALER_CF_ORG}
  cf create-space ${AUTOSCALER_CF_SPACE} -o ${AUTOSCALER_CF_ORG}
  cf bind-security-group public_networks_egress ${AUTOSCALER_CF_ORG} --space ${AUTOSCALER_CF_SPACE}
  
  
  # Set the config file needed for the acceptance tests, the "app" tests need to use a predefined org/space with the ASGs setup
  echo "######################################################################"
  echo "Writing config file for acceptance tests to acceptance/integration_config.json, do not ever print this out into concourse logs!"
  echo "######################################################################"
  
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
  "service_offering_enabled": true,

  "use_existing_organization": true,
  "existing_organization": "${AUTOSCALER_CF_ORG}",
  "use_existing_space": true,
  "existing_space": "${AUTOSCALER_CF_SPACE}",
}
EOF
else
  # Set the config file needed for the acceptance tests, the broker tests fails if it uses an existing org, ASG isn't important
  echo "######################################################################"
  echo "Writing config file for acceptance tests to acceptance/integration_config.json, do not ever print this out into concourse logs!"
  echo "######################################################################"
  
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
fi



export CONFIG=$PWD/integration_config.json

# Set GINKGO_BINARY since its provided in the tarball, omit this to have it built at runtime
export GINKGO_BINARY=$PWD/ginkgo_v2_linux_amd64


# Run the actual test, pick one: {broker, api, app}
echo "######################################################################"
echo "Running ${COMPONENT_TO_TEST} test..."
echo "######################################################################"
./bin/test ${COMPONENT_TO_TEST} #--nodes=4 #--flake-attempts=3



# Perform the cleanup (drops any created org that is named ASATS*)
echo "######################################################################"
echo "Logging in and running cleanup.sh..."
echo "######################################################################"
cf login -a ${CF_API} -u ${CF_ADMIN_USER} -p "${CF_ADMIN_PASSWORD}" -o cloud-gov -s services
./cleanup.sh

echo "######################################################################"
echo "~FIN~"
echo "######################################################################"
