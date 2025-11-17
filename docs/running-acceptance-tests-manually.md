# How to manually run acceptance tests

## Setup the acceptance tests

From the development jumpbox:

```bash
# These come from the pipeline
export CF_API="api.$(credhub get -n /bosh/cf-development/system_domain -q)"
export CF_APPS_DOMAIN="$(credhub get -n /bosh/cf-development/system_domain -q)"
export CF_ADMIN_USER=autoscaler
export CF_ADMIN_PASSWORD="$(credhub get -n /bosh/cf-development/autoscaler-password -q)"
export AUTOSCALER_API="app-autoscaler.$(credhub get -n /bosh/cf-development/system_domain -q)"
export COMPONENT_TO_TEST=app
export AUTOSCALER_CF_ORG=ASATS-Autoscaler-Acceptance-Tests
export AUTOSCALER_CF_SPACE=acceptance-tests
export COMPONENT_TO_TEST=app

# Select the version of autoscaler acceptance tests to use, should use the version of autoscaler releases deployed
#export AS_VERSION="14.4.1"
#export AS_VERSION="14.3.0"
export AS_VERSION="15.9.0"

# Clone the repo with the acceptance tests
wget https://github.com/cloudfoundry/app-autoscaler-release/releases/download/${AS_VERSION}/app-autoscaler-acceptance-tests-v${AS_VERSION}.tgz
tar -xzf app-autoscaler-acceptance*.tgz
cd acceptance

# Log into CF and create the org, space and define the ASG.  These need to exist before running the tests as they are fed into `integration_config.json`
cf login -a ${CF_API} -u ${CF_ADMIN_USER} -p "${CF_ADMIN_PASSWORD}" -o cloud-gov -s services
cf create-org ${AUTOSCALER_CF_ORG}
cf create-space ${AUTOSCALER_CF_SPACE} -o ${AUTOSCALER_CF_ORG}
cf bind-security-group public_networks_egress ${AUTOSCALER_CF_ORG} --space ${AUTOSCALER_CF_SPACE}

# Create acceptance tests configuration file
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

# This env variable is read by the acceptance tests
export CONFIG=$PWD/integration_config.json

# Set GINKGO_BINARY since its provided in the tarball, omit this to have it built at runtime
export GINKGO_BINARY=$PWD/ginkgo_v2_linux_amd64
```

## Running the Acceptance Tests

Continuing on the development jumpbox, the default tests in the pipeline are:

```
./bin/test -v --timeout=2h --skip "cpuutil" ${COMPONENT_TO_TEST} 
                                            ^----- The type of acceptance tests to run.  Set as "app" (used here), "api" or "broker"
                                  ^----- Any Ginkgo test that has this string in it will be skipped
                         ^----- Ginkgo test modifier, allows you to "skip" certain tests that match the string or "focus" to only run tests with a string
              ^---- How long the tests can run before erroring.  Default is an hour, the full test takes longer to run.
            ^----- Verbose output - see all the steps running.  Omit to make the output only show final test result overview
    ^----- Prebuilt acceptance test go app

```

These will take a little over an hour to run.

Other examples of running tests are:

```bash
# Only run tests with the work "label" in the test string, only show final test results
./bin/test --timeout=2h --focus "label" ${COMPONENT_TO_TEST} 

# Same test as previous, but verbosely shows every evaluation command and the corresponding output
./bin/test -v --timeout=2h --focus "label" ${COMPONENT_TO_TEST} 

# These is the failing tests for 14.4.1
./bin/test -v --timeout=2h --focus "bound_app" ${COMPONENT_TO_TEST} 


# These are two of the failing tests for 14.4.1+
./bin/test -v --timeout=2h --focus "mtls" --focus "breach_duration_secs" ${COMPONENT_TO_TEST} 

```


## Clean up after tests

To clean up the CF resources created for the acceptance tests, from the development jumpbox, run:

```bash
cf login -a ${CF_API} -u ${CF_ADMIN_USER} -p "${CF_ADMIN_PASSWORD}" -o cloud-gov -s services
./cleanup.sh
```

This will remove the test org and associated CF resources.