#!/bin/bash

BRANCH="pages"

echo -e "🚢 Pushing to GitHub..."

hugo -d `pwd`

git fetch
git checkout gh-pages

git add .

msg="generate site `date`"
git commit -m "$msg"

# Push source and build repos.
git push origin $BRANCH

popd
