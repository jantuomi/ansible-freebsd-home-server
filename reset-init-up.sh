#!/bin/bash

set -euxo pipefail

./vm.sh reset
./vm.sh init
./vm.sh up

