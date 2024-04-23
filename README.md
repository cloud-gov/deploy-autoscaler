# Deploying autoscaler

This is done in a few steps:

 1. Create an RDS database
 2. Create the uaa client
 3. Create ops files for rds and loggregator certs
 4. Deploy
 5. Register broker
 6. Enable the broker for an organization
 7. Acceptance Tests
 8. Manual Tests
 9. Install plugin


Overall instructions for install are at https://github.com/cloudfoundry/app-autoscaler-release/blob/main/README.md .  While the overall process is correct, many of the details, such as user names and base yaml files to use are incorrect.  These are corrected for in this set of instructions.  With that out of the way, let's deploy!

## 1. Create RDS Database

### Create autoscaler module

See https://github.com/cloud-gov/cg-provision/tree/autoscaler for changes made.



## 2. Create UAA client

Instructions say:

```
uaac client add "autoscaler_client_id" \
    --authorized_grant_types "client_credentials" \
    --authorities "cloud_controller.read,cloud_controller.admin,uaa.resource" \
    --secret <AUTOSCALE_CLIENT_SECRET>
```

We'll need to add this permanently to the cf deploy, so let's modify the manifest instead of using `uaac`, the yaml to add is:


```
instance_groups:
- name: uaa
  jobs:
  - name: uaa
    release: uaa
    properties:
      uaa:
        clients:
          autoscaler_client_id:
            authorized-grant-types: client_credentials
            authorities: cloud_controller.read,cloud_controller.admin,uaa.resource
            secret: "((autoscale_client_secret))"

variables:
- name: autoscale_client_secret
  type: password

```

Converting this to an ops file is:

```
- type: replace
  path: /instance_groups/name=uaa/jobs/name=uaa/properties/uaa/clients/autoscaler_client_id?
  value:
    authorized-grant-types: client_credentials
    authorities: cloud_controller.read,cloud_controller.admin,uaa.resource
    secret: "((autoscaler_client_secret))"

- type: replace
  path: /variables/-
  value:
    name: autoscaler_client_secret
    type: password
```

Dirty deploy this:

```
bosh -d cf-development manifest > cf.yml
vim autoscaler.yml # copy ops file contents above here
bosh -d cf-development deploy cf.yml -o autoscaler.yml
```

Results in:

```
  variables:
+ - name: autoscaler_client_secret
+   type: password
  
  instance_groups:
  - name: uaa
    jobs:
    - name: uaa
      properties:
        uaa:
          clients:
+           autoscaler_client_id:
+             authorities: "<redacted>"
+             authorized-grant-types: "<redacted>"
+             secret: "<redacted>"
```

Added this ops file to be used in  `cg-deploy-cf/ci/pipeline.yml` with https://github.com/cloud-gov/cg-deploy-cf/pull/771

To get the secret back:

```
credhub get -n /bosh/cf-development/autoscaler_client_secret -q
g2REDACTEDy4
```


## 3. Create the ops files for deploying app-autoscaler

These have been created and reside in `bosh/opsfiles`, they are mostly based on upstream versions of the ops files.  The vast majority of the customizations are from autoscaler assuming that the name of the Cloud Foundry is named `cf`, which it is not.

The only remaining task is to upload the release, for some reason there is no built in release structure which includes the release version itself.

```
git clone https://github.com/cloudfoundry/app-autoscaler-release.git
cd app-autoscaler-release

bosh upload-release --sha1 828ddb8484c42c4c4e0eeee401bc684857aacf57 https://bosh.io/d/github.com/cloudfoundry-incubator/app-autoscaler-release?v=11.1.1
```

An ops file named `bosh/opsfiles/releases.yml` now holds the configuration above and is used by the pipeline.

## 4. Deploy

Navigate to [https://ci.fr.cloud.gov/teams/main/pipelines/deploy-autoscaler](https://ci.fr.cloud.gov/teams/main/pipelines/deploy-autoscaler) to deploy via pipeline.


##  5. Register broker

Note: The broker has already been registered in development, staging and production using the instructions below, this activity should not need to be repeated.

Original instructions, which won't work:

```
cf create-service-broker autoscaler autoscaler_service_broker_user `bosh int ./bosh-lite/deployments/vars/autoscaler-deployment-vars.yml --path /autoscaler_service_broker_password` https://autoscalerservicebroker.bosh-lite.com
```

A number of things are wrong with this:

 - We have credhub in play, didn't use a vars store, so to pull the password run:

   ```
   credhub get -n /bosh/app-autoscaler/service_broker_password -q
   ```

 - The username is wrong, in the manifest it is defined as `autoscaler-broker-user`
 - The URL assumes you are using bosh-lite but has the wrong suffix, the format is `app-autoscalerservicebroker.<system_domain>`, the system_domain was pulled from CF and used as a variable when this was deployed

To test the broker is responding with the user, pass and url, run a `curl`:

```
curl "https://autoscaler-broker-user:DcREDACTEDcY@app-autoscalerservicebroker.dev.us-gov-west-1.aws-us-gov.cloud.gov/v2/catalog"
```

This should emit something like:

```
{"services":[{"id":"autoscaler-guid","name":"app-autoscaler","description":"Automatically increase or decrease the number of application instances based on a policy you define.","bindable":true,"instances_retrievable":true,"bindings_retrievable":true,"tags":["app-autoscaler"],"plan_updateable":false,"plans":[{"id":"autoscaler-free-plan-id","name":"autoscaler-free-plan","description":"This is the free service plan for the Auto-Scaling service.","plan_updateable":true},{"id":"acceptance-standard","name":"acceptance-standard","description":"This is the standard service plan for the Auto-Scaling service.","plan_updateable":false}]}]}
```

If you get back `Unauthorized` you have the wrong user or password.

Now that the broker responds with curl, log into the cf cli as an admin and run:

```
cf create-service-broker autoscaler autoscaler-broker-user DcREDACTEDcY https://app-autoscalerservicebroker.dev.us-gov-west-1.aws-us-gov.cloud.gov
```

If successful, you should see:

```
Creating service broker autoscaler as platform.operator...
OK
```

##  6. Enable the broker for an organization

There are two ways of enabling service access: via the pipeline and manually


### Enable via the pipeline (Preferred)

The pipeline uses [https://github.com/cloud-gov/cg-pipeline-tasks/blob/main/set-plan-visibility.yml](https://github.com/cloud-gov/cg-pipeline-tasks/blob/main/set-plan-visibility.yml) to set the list of orgs to enable the broker access.  To add additional organizations, modify the `cg-deploy-autoscaler.yml` secrets file, the list of orgs are space delimited: 

```
cf:
  development:
    service_organization: org1 org2 org3
  staging:
    service_organization: org1 org2
  production:
    service_organization: org3 org4 org5
```

### Manual enabling (Debugging)

To enable the service broker for the `cloud-gov-operators` org:

```
cf enable-service-access app-autoscaler -o cloud-gov-operators

Enabling access to all plans of service offering app-autoscaler for org cloud-gov-operators as platform.operator...
OK
```

##  7. Acceptance Tests

The app-autoscaler-release as part of their releases includes a tarball with a precompiled test app for each release version, see this link for the [12.1.1 example](https://github.com/cloudfoundry/app-autoscaler-release/releases/download/v12.1.1/app-autoscaler-acceptance-tests-v12.1.1.tgz).  To use this tarball, you'll need to configure a `integration_config.json` with information, such as a cf user, cf api, broker credentials and other bits of information.  Once this is done, there are tests that you can run as `./bin/test test-type`.

These contain three types of tests:

 - broker - ~5 minutes to run
 - api - ~5 minutes to run
 - app - currently paused since custom metrics are not working and the test takes ~1 hour to run

In the pipeline for `cg-deploy-autoscaler`, each of these tests are configured to run after the deployment of development, staging and production as `acceptance-tests-{api,broker,app}-{development,staging,production}`.  These tests are configured to not run in parallel as each runs a `cleanup.sh` script at the end which deletes orgs with the naming convention `ASATS-*`.


##  8. Manual Tests


Create a service instance:

```
cf create-service app-autoscaler  autoscaler-free-plan  my-autoscaler
```


Create the scaling policy, unique for this service instance:

```
cat << POLICY > my_policy.json
{
  "instance_min_count": 1,
  "instance_max_count": 4,
  "scaling_rules":
  [
   {
    "metric_type":"cpu",
    "breach_duration_secs":60,
    "threshold": 10,
    "operator":"<=",
    "cool_down_secs":60,
    "adjustment": "-1"
   },
   {
    "metric_type": "cpu",
    "breach_duration_secs": 60,
    "threshold": 50,
    "operator": ">",
    "cool_down_secs": 60,
    "adjustment": "+1"
   }   
  ]
}
POLICY
```


Now bind the service instance and policy to the sample app called `my_cf3_app`:

```
cf bind-service my_cf3_app my-autoscaler -c my_policy.json
```

This will apply an autoscaler policy to the `my_cf3_app` which will keep the number of app instances between 1 and 4, scaling -/+ 1 app instance based on whether the CPU is under 10% or over 50%.


To show this working, first scale the app instances to 6 manually, you will see 6 app instances started:

```
cf scale -i 6 my_cf3_app

...
memory usage:   256M
     state      since                  cpu    memory          disk           details
#0   running    2023-09-20T11:38:04Z   0.3%   52.8M of 256M   130.6M of 1G   
#1   starting   2023-09-20T17:40:47Z   0.0%   0 of 0          0 of 0         
#2   starting   2023-09-20T17:40:47Z   0.0%   0 of 0          0 of 0         
#3   starting   2023-09-20T17:40:47Z   0.0%   0 of 0          0 of 0         
#4   starting   2023-09-20T17:40:47Z   0.0%   0 of 0          0 of 0         
#5   starting   2023-09-20T17:40:47Z   0.0%   0 of 0          0 of 0         
```

After a minute or so you'll see the number of app instances drop to 4 as this is what the upper boundary was set to:

```
platform.operator@FCOH2J-FWR2F7YT cf-deployment % cf app my_cf3_app
...
instances:      4/4
memory usage:   256M
     state     since                  cpu     memory          disk           details
#0   running   2023-09-20T11:38:04Z   0.2%    52.8M of 256M   130.6M of 1G   
#1   running   2023-09-20T17:40:58Z   11.6%   49.4M of 256M   130.6M of 1G   
#2   running   2023-09-20T17:40:53Z   0.0%    53.1M of 256M   130.6M of 1G   
#3   running   2023-09-20T17:40:58Z   13.3%   49.3M of 256M   130.6M of 1G   
```

Since there is no load on this hello-world style app, you'll then see the number of application instances from 4, to 3, to 2, to 1 over the course of 8 or so minutes.

### To test the scale up, we'll need to add load and drop the threshold

Start by creating a new policy with an 11% scale up threshold:

```
cat << POLICY > my_policy.json
{
  "instance_min_count": 1,
  "instance_max_count": 4,
  "scaling_rules":
  [
   {
    "metric_type":"cpu",
    "breach_duration_secs":60,
    "threshold": 10,
    "operator":"<=",
    "cool_down_secs":60,
    "adjustment": "-1"
   },
   {
    "metric_type": "cpu",
    "breach_duration_secs": 60,
    "threshold": 11,
    "operator": ">",
    "cool_down_secs": 60,
    "adjustment": "+1"
   }   
  ]
}
POLICY
```

Unbind then bind the service instance to the app to have the policy applied, then verify the policy is dropped to 11%:

```
cf unbind-service my_cf3_app my-autoscaler
cf bind-service my_cf3_app my-autoscaler -c my_policy.json
cf asp my_cf3_app
```
The last command uses the CF App Autoscaler plugin, see the next section for installation.  This can be skipped without impacting the test.


In a separate window, run the following script:

```
#!/bin/bash

set -x # run in debug mode
DURATION=300 # how long should load be applied ? - in seconds
TPS=60 # number of requests per second
end=$((SECONDS+$DURATION))
#start load
while [ $SECONDS -lt $end ];
do
        for ((i=1;i<=$TPS;i++)); do
                curl https://my_cf3_app.dev.us-gov-west-1.aws-us-gov.cloud.gov  -o /dev/null -s -w '%{time_starttransfer}\n' >> response-times.log &
        done
        sleep 1
done
wait
echo "Load test has been completed"
```

After 3 minutes you should see the number of application instances scale up to 2:

```
cf app my_cf3_app
...
instances:      2/2
memory usage:   256M
     state     since                  cpu    memory          disk           details
#0   running   2023-09-20T11:38:03Z   6.4%   73.1M of 256M   130.6M of 1G   
#1   running   2023-09-20T19:36:15Z   6.7%   60.7M of 256M   130.6M of 1G  
```

Yay!


## 9. Install plugin

To gain more insight and view the audit trail of the app scaling up and down there is a CF plugin which can be installed:

```
cf install-plugin -r CF-Community app-autoscaler-plugin
cf autoscaling-api https://app-autoscaler.dev.us-gov-west-1.aws-us-gov.cloud.gov
```

Once installed you can view the history with of the scaling event above:

```
cf autoscaling-history my_cf3_app

Retrieving scaling event history for app my_cf3_app...
Scaling Type            Status          Instance Changes        Time                            Action                                                          Error     
dynamic                 succeeded       2->1                    2023-09-20T15:38:09-04:00       -1 instance(s) because cpu <= 10percentage for 60 seconds            
dynamic                 succeeded       1->2                    2023-09-20T15:36:09-04:00       +1 instance(s) because cpu > 11percentage for 60 seconds 
dynamic                 succeeded       2->1                    2023-09-20T13:48:09-04:00       -1 instance(s) because cpu <= 10percentage for 60 seconds            
dynamic                 succeeded       3->2                    2023-09-20T13:46:09-04:00       -1 instance(s) because cpu <= 10percentage for 60 seconds            
dynamic                 succeeded       4->3                    2023-09-20T13:44:09-04:00       -1 instance(s) because cpu <= 10percentage for 60 seconds            
dynamic                 succeeded       6->4                    2023-09-20T13:42:09-04:00       -2 instance(s) because limited by max instances 4                    
```

To see the CPU metrics for which the scaling up and down was decided upon, run:

```
cf autoscaling-metrics my_cf3_app cpu

Retrieving aggregated cpu metrics for app my_cf3_app...
Metrics Name            Value                   Timestamp     
cpu                     1percentage             2023-09-20T14:02:48-04:00     
cpu                     1percentage             2023-09-20T14:02:08-04:00     
cpu                     1percentage             2023-09-20T14:01:28-04:00     
cpu                     1percentage             2023-09-20T14:00:48-04:00   
...
```


