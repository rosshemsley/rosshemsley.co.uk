#!/bin/bash

set -euxo pipefail

echo -e "🚢 Pushing to GitHub..."

git checkout gh-pages
pushd rosshemsley.co.uk
hugo -d .

# git add .

# msg="generate site `date`"
# git commit -m "$msg"


# git push origin gh-pages

popd
