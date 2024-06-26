#!/bin/bash

# Execute by: bash xxx.sh or bash zzz/yyy/xxx.sh or ./xxx.sh or ./zzz/yyy/xxx.sh source xxx.sh
REALPATH=$(realpath ${BASH_SOURCE[0]})
SCRIPT_DIR=$(cd $(dirname ${REALPATH}) && pwd)
WORK_DIR=$(cd $(dirname ${REALPATH})/.. && pwd)
echo "BASH_SOURCE=${BASH_SOURCE}, REALPATH=${REALPATH}, SCRIPT_DIR=${SCRIPT_DIR}, WORK_DIR=${WORK_DIR}"
cd ${WORK_DIR}

help=no
refresh=no
target=

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) help=yes; shift ;;
        -refresh|--refresh) refresh=yes; shift ;;
        -target|--target) target="$2"; shift 2;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
done

if [[ "$help" == yes ]]; then
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -h, --help           Show this help message and exit"
    echo "  -refresh, --refresh  Refresh current tag. Default: no"
    echo "  -target, --target    The target version to release, for example, v5.7.28"
    exit 0
fi

if [[ ! -z $target ]]; then
    RELEASE=$target
    refresh=yes
else
    RELEASE=$(git describe --tags --abbrev=0 --match v*)
fi
if [[ $? -ne 0 ]]; then echo "Release failed"; exit 1; fi

REVISION=$(echo $RELEASE|awk -F . '{print $3}')
if [[ $? -ne 0 ]]; then echo "Release failed"; exit 1; fi

let NEXT=$REVISION+1
if [[ $refresh == yes ]]; then
  let NEXT=$REVISION
fi
echo "Last release is $RELEASE, revision is $REVISION, next is $NEXT"

MINOR=$(echo $RELEASE |awk -F '.' '{print $2}')
VERSION="5.$MINOR.$NEXT" &&
TAG="v$VERSION" &&
BRANCH=$(git branch |grep '*' |awk '{print $2}') &&
echo "publish version $VERSION as tag $TAG, BRANCH=${BRANCH}"
if [[ $? -ne 0 ]]; then echo "Release failed"; exit 1; fi

######################################################################
if [[ $(grep -q "const version = \"$TAG\"" platform/version.go || echo no) == no ]]; then
    VERSION0="sed -i '' 's|const version = \".*\"|const version = \"$TAG\"|g' platform/version.go"
fi
if [[ $(grep versions scripts/setup-aapanel/info.json | grep -q $VERSION || echo no) == no ]]; then
    VERSION1="sed -i '' 's|\"versions\": \".*\"|\"versions\": \"$VERSION\"|g' scripts/setup-aapanel/info.json"
fi
if [[ $(grep versions scripts/setup-bt/info.json | grep -q $VERSION || echo no) == no ]]; then
    VERSION2="sed -i '' 's|\"versions\": \".*\"|\"versions\": \"$VERSION\"|g' scripts/setup-bt/info.json"
fi
if [[ $(grep application_version scripts/setup-droplet/srs.json |grep -v user | grep -q $VERSION || echo no) == no ]]; then
    VERSION3="sed -i '' 's|\"application_version\": \".*\"|\"application_version\": \"$VERSION\"|g' scripts/setup-droplet/srs.json"
fi
if [[ $(grep 'git clone -b' scripts/setup-droplet/scripts/01-srs.sh |grep -q $BRANCH || echo no) == no ]]; then
    VERSION4="sed -i '' 's|git clone -b main|git clone -b $BRANCH|g' scripts/setup-droplet/scripts/01-srs.sh"
fi
if [[ ! -z $VERSION0 || ! -z $VERSION1 || ! -z $VERSION2 || ! -z $VERSION3 || ! -z $VERSION4 ]]; then
    echo "Please update version to $VERSION"
    if [[ ! -z $VERSION0 ]]; then echo "    $VERSION0 &&"; fi
    if [[ ! -z $VERSION1 ]]; then echo "    $VERSION1 &&"; fi
    if [[ ! -z $VERSION2 ]]; then echo "    $VERSION2 &&"; fi
    if [[ ! -z $VERSION3 ]]; then echo "    $VERSION3 &&"; fi
    if [[ ! -z $VERSION4 ]]; then echo "    $VERSION4 &&"; fi
    echo "    echo ok"
    exit 1
fi

git st |grep -q 'nothing to commit'
if [[ $? -ne 0 ]]; then
  echo "Failed: Please commit before release";
  exit 1
fi

git fetch origin
if [[ $(git status |grep -q 'Your branch is up to date' || echo 'no') == no ]]; then
  git status
  echo "Failed: Please sync before release";
  exit 1
fi
echo "Sync OK"

git fetch gitee
if [[ $(git diff origin/${BRANCH} gitee/${BRANCH} |grep -q diff && echo no) == no ]]; then
  git diff origin/${BRANCH} gitee/${BRANCH} |grep diff
  echo "Failed: Please sync gitee ${BRANCH} before release";
  exit 1
fi
echo "Sync gitee OK"

######################################################################
git tag -d $TAG 2>/dev/null; git push origin :$TAG 2>/dev/null; git push gitee :$TAG 2>/dev/null
echo "Delete tag OK: $TAG"

git tag $TAG && git push origin $TAG && git push gitee $TAG
echo "Publish OK: $TAG"

echo -e "\n\n"
echo "Publication ok, please visit"
echo "    Please test it after https://github.com/ossrs/oryx/actions/workflows/release.yml done"
echo "    Download bt-oryx.zip from https://github.com/ossrs/oryx/releases"
echo "    Then submit it to https://www.bt.cn/developer/details.html?id=600801805"
echo "    Finally, update release at https://gitee.com/ossrs/oryx/releases/new"
