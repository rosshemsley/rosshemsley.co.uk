#!/bin/bash

set -euxo pipefail

echo -e "🚢 Pushing to GitHub..."

pushd rosshemsley.co.uk
hugo -d .

git checkout gh-pages
# git add .

# msg="generate site `date`"
# git commit -m "$msg"


# git push origin gh-pages

popd
