#!/bin/bash

set -euxo pipefail

echo -e "🚢 Pushing to GitHub..."
pushd rosshemsley.co.uk

if [[ $(git status -s) ]]
then
    echo "The working directory is dirty. giving up"
    exit 1;
fi

rm -rf public
mkdir public
git worktree prune
popd
rm -rf .git/worktrees/public/
git worktree add rosshemsley.co.uk/public --checkout origin/gh-pages
pushd rosshemsley.co.uk
rm -rf public/*

hugo

cp ../CNAME ./public/

cd public && git add --all && git commit -m "Publishing to gh-pages"
git push origin/gh-pages HEAD:gh-pages
