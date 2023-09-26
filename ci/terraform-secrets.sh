#!/bin/bash

bosh interpolate \
  autoscaler-manifests/bosh/varsfiles/terraform.yml \
  -l terraform-yaml/state.yml \
  > terraform-secrets/terraform.yml
