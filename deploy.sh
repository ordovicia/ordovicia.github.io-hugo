#!/bin/bash

set -e

hugo

cd public
git add .
LANG=C msg="Rebuilding site at $(date). ($(hugo version))"
git commit -m "$msg"
git push origin master
