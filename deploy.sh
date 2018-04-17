#!/bin/bash

set -e

hugo

cd public
git add .
LANG=C msg=${1:-"rebuilding site $(date)"}
git commit -m "$msg"
git push origin master
