# get tag name from ENV.GITHUB-TAG
# removes origin README.md
# to this format:

# # Life@USTC v1.0.1-pre-appstore
#
# Bug fix branch for v1.0.1, no new features would be added.
#
# v1.0.1 is expected to be submitted at 2023-07-05, 30 days after this branch is created.

TAG=$GITHUB_TAG
if [ -z "$TAG" ]; then
    echo "GITHUB_TAG is not set, exiting..."
    exit 1
fi

# remove origin README.md (if exists)
rm -f README.md

# create new README.md
echo "# Life@USTC $TAG" >> README.md
echo "" >> README.md
echo "Bug fix branch for $TAG, no new features would be added." >> README.md
echo "" >> README.md
echo "$TAG is expected to be submitted on $(date -v+30d +%Y-%m-%d), 30 days after this branch is created." >> README.md