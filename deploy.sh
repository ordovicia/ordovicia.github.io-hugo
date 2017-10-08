#!/bin/bash

set -e

hugo
cd public
msg=${1:-"rebuilding site $(date)"}
git commit -am "$msg"
git push origin master
