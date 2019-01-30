#!/bin/bash

# Image and repository name to pull images.
IMGNAME=joshuarobinson/ior

# NFS Data VIP and filesystem name to test against. Assumes filesystem already
# created and configured with NFS access.
DATAHUB_IP="10.62.64.200"
DATAHUB_FS="ior-benchmark"

# Name of Ansible host group for MPI workers.
HOSTGROUP="irp210"

# Degree of concurrency to use in testing.
CONC=960

# Port range used by MPI, configured in Dockerfile.
PORTRANGE="24000-24100"

if [ "$1" == "start" ]; then
	echo "Starting MPI workers"

	# Rebuild docker image and ensure that all nodes have latest version.
	./build_image.sh
	ansible $HOSTGROUP -a "docker pull $IMGNAME"

	# Create a hostfile group from ansible to inject into master when
	# running tests so that it can find all  workers.
	if [ ! -e hostfile ]; then
		echo "Generating 'hostfile' from ansible group $HOSTGROUP"
		ansible-inventory --list $HOSTGROUP | jq ".$HOSTGROUP.hosts[]" | xargs dig +short +search > hostfile
	fi

	# Create docker volume for NFS mount to test.
	ansible $HOSTGROUP -a "docker volume create --driver local --opt type=nfs --opt o=addr=$DATAHUB_IP,rw \
		--opt=device=:/$DATAHUB_FS iorscratch"

	# Start worker containers.
	ansible $HOSTGROUP -a "docker run -d --rm \
		-p 2222:22 \
		-p $PORTRANGE:$PORTRANGE \
		--name=mpi-ior \
		--add-host=ior-master:$(hostname -i) \
		-v iorscratch:/scratch \
		$IMGNAME \
		sudo /usr/sbin/sshd -D"

elif [ "$1" == "stop" ]; then
	echo "Stopping MPI workers"
	ansible $HOSTGROUP -a "docker stop mpi-ior"
	ansible $HOSTGROUP -a "docker volume rm iorscratch"

elif [ "$1" == "run" ]; then

	# Depending on which test, choose the command-line invocation and
	# options. Both tests are launched in the same way below.
	if [ "$2" == "ior" ]; then
		echo "Running IOR benchmark"
		# -B: use ODIRECT IO
		# -F: use a unique file per worker
		TESTCMD="ior -v -B -w -r -i 3 -F -o /scratch/foo/iorfile -t 4M -b 2G"
	
	elif [ "$2" == "mdtest" ]; then
		echo "Running mdtest benchmark"
		# -b: branching factor
		# -z: tree depth
		# -I: items per directory
		TESTCMD="mdtest -b 3 -v -z 3 -u -I 3000 -i 1 -d /scratch/foo"
	
	else
		echo "Error $2 not a valid benchmark. Options: ior|mdtest"
		exit 2
	fi

	# Launch test using the localhost to run the master.	
	docker run -it --rm --name=ior-master \
		--hostname=ior-master \
		-p $PORTRANGE:$PORTRANGE \
		-v iorscratch:/scratch \
		-v ${PWD}/hostfile:/project/hostfile \
		$IMGNAME \
		mpiexec -f /project/hostfile -n $CONC $TESTCMD

else
	echo "Usage: $0 [start|stop|run]"
	echo "start|stop brings up or down the MPI workers."
	echo "$0 run ior|mdtest will run the desired benchmark."
fi
