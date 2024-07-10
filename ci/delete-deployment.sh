#!/bin/bash

set -eu

echo "Tearing down..."

bosh -n delete-deployment -d app-autoscaler
