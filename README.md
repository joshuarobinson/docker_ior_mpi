# IOR MPI Benchmark on Docker 

Many thanks to that great work by Nikyle Nguyen
[here](https://github.com/NLKNguyen/alpine-mpich) to create an MPI base image that I built upon.

# How it works:
These scripts create a set of MPI workers inside of docker containers on nodes
specified via Ansible hostgroup. To run benchmarks, a container is started on
the local node as master.

## Docker image:

Dockerfile and build_image.sh - Use the build_image.sh wrapper to set
arguments, build,  and push final image to repository.

## Scripts:

control_mpi.sh - bash script to orchestrate 1) starting and stopping all MPI
workers and 2) running ior or mdtest benchmarks.

recreate-test-filesystem.py -- python script that use the FB REST API to create
a fresh filesystem for IOR testing.

## Steps to use:
 * Install software dependencies: docker, ansible, jq 
 * Setup Ansible host group for all nodes that will participate as MPI workers.
   Update HOSTGROUP variable in control_mpi.sh script.
 * Create and configure an NFS filesystem, update DATAHUB_XY with NFS IP and
   export name. Optionally, use included python script to create filesystem.
 * Update REPONAME (build_image.sh) and IMGNAME (control_mpi.sh) to point to a
   repository to store the docker image.
 * Update CONC to the number of parallel tasks to launch. Recommend value is
   the total core count in cluster.
 * Execute "control_mpi.sh start" to bring up the MPI workers. This step also
   builds and distributes the docker image and creates a hostfile for running
   tests.
 * Run benchmark with "control_mpi.sh run ior|mdtest"
