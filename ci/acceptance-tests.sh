#!/bin/bash

set -eu

#CF_API_URL=$(echo "${CF_API_URL}" | sed 's/\/$//')

echo "GOLANG_VERSION passed in is: ${GOLANG_VERSION}"

echo "This is the installed go version: $(go version)"

echo "This is the installed cf cli version: $(cf -v)"