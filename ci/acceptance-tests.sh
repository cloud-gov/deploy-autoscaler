#!/bin/bash

set -eu
echo "######################################################################"
echo "This is the installed go version: $(go version)"
echo "This is the installed cf cli version: $(cf -v)"
echo "######################################################################"

# Get the tarball with the test
cd autoscaler-acceptance
tar -xzf app-autoscaler-acceptance*.tgz
cd acceptance

if [[ "$COMPONENT_TO_TEST" = "app" ]]; then 

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
  
  "node_memory_limit": 1024
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

echo "######################################################################"
echo "Running ${COMPONENT_TO_TEST}, skip 4 test with 'disable', 'mtls' or 'lead' in it..."
echo "######################################################################"

case $COMPONENT_TO_TEST in
  "api")
       echo "Running API tests"
       cd api
       ./api_linux_amd64.test
       break
       ;;
   "app")
       echo "Running App tests"
       cd app
       ./app_linux_amd64.test --ginkgo.timeout 2h --ginkgo.skip "disable"  --ginkgo.skip "mtls" --ginkgo.skip "lead"
       break
       ;;
   "broker")
       echo "Running Broker tests"
       cd broker
       ./broker_linux_amd64.test 
       break
       ;;
   *) echo "Invalid selection $COMPONENT_TO_TEST";;
esac

cd ..


# Perform the cleanup (drops any created org that is named ASATS*)
echo "######################################################################"
echo "Logging in and running cleanup.sh..."
echo "######################################################################"
cf login -a ${CF_API} -u ${CF_ADMIN_USER} -p "${CF_ADMIN_PASSWORD}" -o cloud-gov -s services
./cleanup.sh

echo "######################################################################"
echo "~FIN~"
echo "######################################################################"
