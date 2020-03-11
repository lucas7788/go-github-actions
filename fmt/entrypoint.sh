#!/bin/bash
set -e

cd "${GO_WORKING_DIR:-.}"

# Build ignored directories
IGNORED_DIRS=""
if [ -n "${GO_IGNORE_DIRS}" ]; then
  IGNORE_DIRS_ARR=($GO_IGNORE_DIRS)
  for DIR in "${IGNORE_DIRS_ARR[@]}"; do
    # If the directory doesn't end in "/*", add it
    if [[ ! "${DIR}" =~ .*\/\*$ ]]; then
      DIR="${DIR}/*"
    fi
    # Append to our list of directories to ignore
    IGNORED_DIRS+=" -not -path \"${DIR}\""
  done
fi

# Use an eval to avoid glob expansion
FIND_EXEC="find . -type f -iname '*.go' ${IGNORED_DIRS}"

# Get a list of files that we are interested in
CHECK_FILES=$(eval ${FIND_EXEC})

# Check if any files are not formatted.
set +e
test -z "$(gofmt -l -d -e ${CHECK_FILES})"
SUCCESS=$?
set -e

# Exit if `go fmt` passes.
if [ $SUCCESS -eq 0 ]; then
  exit 0
fi

# Get list of unformatted files.
set +e
ISSUE_FILES=$(gofmt -l ${CHECK_FILES})
echo "${ISSUE_FILES}"
set -e

# Iterate through each unformatted file.
OUTPUT=""
for FILE in $ISSUE_FILES; do
DIFF=$(gofmt -d -e "${FILE}")
OUTPUT="$OUTPUT
\`${FILE}\`

\`\`\`diff
$DIFF
\`\`\`
"
done

git checkout master
git add -A
timestamp=$(date -u)
git commit -m "Automated publish: ${timestamp} ${GITHUB_SHA}" || exit 0
git pull --rebase publisher master
git push publisher master

exit $SUCCESS
