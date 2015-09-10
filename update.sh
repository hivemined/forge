#!/bin/sh
####
## Install Forge and Minecraft versions and update documentation
##
## Usage:
##    update.sh <forge installer> [--force]
####

# toggle git integration
if [ "$2" = --git ]; then
    __ENABLE_GIT=1
else
    __ENABLE_GIT=0
fi

# determine target version and installer
# default to latest available installer
if [ -z "$1" ]; then
    forge_installer=$(ls -1r "$(dirname $0)/installers" | head -n 1)
    FORGE_VERSION=$(echo "$forge_installer" | sed "s/^.*-\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)-.*/\1/")
    MINECRAFT_VERSION=$(echo "$forge_installer" | sed "s/^.*-\([0-9]\+\.[0-9]\+\.[0-9]\+\)-.*/\1/")

# validate input formatting and check for installer
elif echo "$1" | grep -qE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"; then
    if ls -1 "$(dirname $0)/installers" | grep -q forge.*-$1-.*installer.jar; then
        forge_installer=$(ls -1t "$(dirname $0)/installers" | grep forge.*-$1-.*installer.jar | head -n 1)
        FORGE_VERSION="$1"
        MINECRAFT_VERSION=$(echo "$forge_installer" | sed "s/^.*-\([0-9]\+\.[0-9]\+\.[0-9]\+\)-.*/\1/")
    else
        echo "No installer found for Forge version: $1"
        exit 1
    fi
else
    echo "$1 is not a valid Forge version format!"
    exit 1
fi

# fetch current version for comparison
OLD_VERSION=$(grep 'FORGE_VERSION=' "$(dirname $0)/Dockerfile" | sed "s/^.*FORGE_VERSION=\([0-9][0-9.]*[0-9]\).*/\1/")

echo "$OLD_VERSION  --->  $FORGE_VERSION"

# determine if an update is needed by comparing current and target versions
if [ "$OLD_VERSION" != "$FORGE_VERSION" ]; then
    echo "Updating Forge to newer version now!"

    # set version information in Dockerfile
    sed -i "s/\(MINECRAFT_VERSION=\)[0-9][0-9.]*[0-9]/\1${MINECRAFT_VERSION}/" "$(dirname $0)/Dockerfile"
    sed -i "s/\(FORGE_VERSION=\)[0-9][0-9.]*[0-9]/\1${FORGE_VERSION}/" "$(dirname $0)/Dockerfile"

    # set version information in README.md
    sed -i "s/\(Current Version: \)[0-9][0-9.]*[0-9]/\1${FORGE_VERSION}/" "$(dirname $0)/README.md"

    # enter build directory
    cd "$(dirname $0)/src"

    # clean previous installation files
    if [ $__ENABLE_GIT = 1 ]; then
        git rm -rf libraries forge-*-universal.jar minecraft_server.*.jar
    else
        rm -rf libraries forge-*-universal.jar minecraft_server.*.jar
    fi

    # install new version of forge
    java -jar "../installers/$forge_installer" --installServer
    rm -f "${forge_installer}.log"

    cd ..

    # update git repository with new tag
    if [ $__ENABLE_GIT = 1 ]; then
        git add README.md Dockerfile src/
        git commit -m "Update to $FORGE_VERSION" && \
		git tag "$FORGE_VERSION" && git push && git push origin "$FORGE_VERSION"
    fi
else
    echo "Forge image already up to date! Staying at version $OLD_VERSION"
fi

