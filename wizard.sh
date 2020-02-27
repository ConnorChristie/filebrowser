#!/bin/bash

set -e

untracked="(untracked)"
REPO=$(cd $(dirname $0); pwd)
COMMIT_SHA=$(git rev-parse --short HEAD)
ASSETS="false"
BINARY="false"
RELEASE=""

debugInfo () {
  echo "Repo:           $REPO"
  echo "Build assets:   $ASSETS"
  echo "Build binary:   $BINARY"
  echo "Release:        $RELEASE"
}

buildAssets () {
  cd $REPO
  rm -rf frontend/dist
  rm -f http/rice-box.go

  cd $REPO/frontend

  if [ "$CI" = "true" ]; then
    npm ci
  else
    npm install
  fi

  npm run lint
  npm run build
}

buildBinary () {
  if ! [ -x "$(command -v rice)" ]; then
    go install github.com/GeertJohan/go.rice/rice
  fi

  cd $REPO/http
  rm -rf rice-box.go
  rice embed-go

  cd $REPO

  declare -a OSES=("darwin" "linux")
  declare -a ARCHES=("amd64" "arm" "arm64")

  for os in "${OSES[@]}"
  do
    for arch in "${ARCHES[@]}"
    do
      GOOS=$os
      GOARCH=$arch

      go build -a -o out/filebrowser-$GOOS-$GOARCH -ldflags "-s -w -X github.com/ConnorChristie/filebrowser/v2/version.CommitSHA=$COMMIT_SHA"
    done
  done

  GOOS=windows
  GOARCH=amd64

  go build -a -o out/filebrowser-$GOOS-$GOARCH.exe -ldflags "-s -w -X github.com/ConnorChristie/filebrowser/v2/version.CommitSHA=$COMMIT_SHA"
}

release () {
  cd $REPO

  echo "👀 Checking semver format"

  if [ $# -ne 1 ]; then
    echo "❌ This release script requires a single argument corresponding to the semver to be released. See semver.org"
    exit 1
  fi

  GREP="grep"
  if [ -x "$(command -v ggrep)" ]; then
    GREP="ggrep"
  fi

  semver=$(echo "$1" | $GREP -P '^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)')

  if [ $? -ne 0 ]; then
    echo "❌ Not valid semver format. See semver.org"
    exit 1
  fi

  go get github.com/tcnksm/ghr
  ghr -t $GITHUB_TOKEN -u $CIRCLE_PROJECT_USERNAME -r $CIRCLE_PROJECT_REPONAME -c $CIRCLE_SHA1 -delete $VERSION ./out/
}

usage() {
  echo "Usage: $0 [-a] [-c] [-b] [-r <string>]" 1>&2;
  exit 1;
}

DEBUG="false"

while getopts "bacr:d" o; do
  case "${o}" in
    b)
      ASSETS="true"
      BINARY="true"
      ;;
    a)
      ASSETS="true"
      ;;
    c)
      BINARY="true"
      ;;
    r)
      RELEASE=${OPTARG}
      ;;
    d)
      DEBUG="true"
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

if [ "$DEBUG" = "true" ]; then
  debugInfo
fi

if [ "$ASSETS" = "true" ]; then
  buildAssets
fi

if [ "$BINARY" = "true" ]; then
  buildBinary
fi

if [ "$RELEASE" != "" ]; then
  release $RELEASE
fi
