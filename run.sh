#!/bin/bash

cd $(dirname $0)

if [[ $OSTYPE == "darwin"* ]]; then
	SOURCE=$(stat -f %N $(pwd)/android)
	CCACHE=$(stat -f %N $(pwd)/ccache)
else
	SOURCE=$(readlink -f $(pwd)/android)
	CCACHE=$(readlink -f $(pwd)/ccache)
fi

CONTAINER_HOME=/home/build
CONTAINER=lineageos
REPOSITORY=bha1/lineageos
TAG=cm-14.1
FORCE_BUILD=0
PRIVILEGED=

while [[ $# > 0 ]]; do
	key="$1"
	case $key in
		-r|--rebuild)
			FORCE_BUILD=1
			;;
		-u|--enable-usb)
			PRIVILEGED="--privileged -v /dev/bus/usb:/dev/bus/usb"
			;;
		*)
			shift # past argument or value
			;;
	esac
	shift
done

# Create shared folders
mkdir -p $SOURCE
mkdir -p $CCACHE

# Build image if needed
IMAGE_EXISTS=$(sudo docker images $REPOSITORY)
if [ $? -ne 0 ]; then
	echo "sudo docker command not found"
	exit $?
elif [[ $FORCE_BUILD = 1 ]] || ! echo "$IMAGE_EXISTS" | grep -q "$TAG"; then
	# Pull Ubuntu image to be sure it's up to date
	echo "Fetching sudo docker \"ubuntu\" image..."
	sudo docker pull ubuntu:16.04

	echo "Building sudo docker image $REPOSITORY:$TAG..."
	sudo docker build -t $REPOSITORY:$TAG .
	OK=$?

	# After successful build, delete existing containers
	IS_EXISTING=$(sudo docker inspect -f '{{.Id}}' $CONTAINER 2>/dev/null)
	if [[ $OK -eq 0 ]] && [[ -n "$IS_EXISTING" ]]; then
		sudo docker rm $CONTAINER
	fi
fi

if [[ $OK -ne 0 ]]; then
	exit 1
fi

# With the given name $CONTAINER, reconnect to running container, start
# an existing/stopped container or run a new one if one does not exist.
IS_RUNNING=$(sudo docker inspect -f '{{.State.Running}}' $CONTAINER 2>/dev/null)
if [[ $IS_RUNNING == "true" ]]; then
	sudo docker attach $CONTAINER
elif [[ $IS_RUNNING == "false" ]]; then
	sudo docker start -i $CONTAINER
else
	sudo docker run $PRIVILEGED -v $SOURCE:$CONTAINER_HOME/android:Z -v $CCACHE:/srv/ccache:Z -i -t --name $CONTAINER $REPOSITORY:$TAG
fi

exit $?
