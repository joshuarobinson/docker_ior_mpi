FROM nlknguyen/alpine-mpich

# Install packages necessary to build and run IOR.
RUN sudo apk add --no-cache autoconf automake bash curl git openssh

# Clone the IOR source code, build, and install.
RUN git clone https://github.com/hpc/ior.git \
	&& cd ior && ./bootstrap && ./configure && make && sudo make install

# Add ssh server host keys and update hostfile to enable passwordless
# communication amongst images.
USER root
RUN cd /etc/ssh/ && ssh-keygen -A -N ''  \
	&& echo "PasswordAuthentication no" >> /etc/ssh/sshd_config  \
	# Unlock for passwordless access. \
	&& passwd -u mpi

ARG RFVER=1.0.0-beta.5
RUN curl http://pure-artifactory.dev.purestorage.com/artifactory/iridium-artifacts/rapidfile/rapidfile-toolkit/$RFVER/rapidfile-$RFVER.tar \
	| tar -xv -C /tmp \
	&& tar -xzvf /tmp/rapidfile-$RFVER/rapidfile-$RFVER-Linux.tgz -C /usr/local/bin/ \
	&& ls /usr/local/bin
RUN pfind --version

# Switch back to mpi user to configure ssh keys.
USER mpi

# Configuration: generate ssh keys for passwordless access and direct all ssh
# connections to port 2222.
RUN mkdir -p /home/mpi/.ssh && ssh-keygen -f /home/mpi/.ssh/id_rsa -t rsa -N '' \
	&& cat /home/mpi/.ssh/id_rsa.pub >> /home/mpi/.ssh/authorized_keys \
	# Disable host key checking and direct all SSH to a custom port. \
	&& echo "StrictHostKeyChecking no" >> /home/mpi/.ssh/config \
	&& echo "LogLevel ERROR" >> /home/mpi/.ssh/config \
	&& echo "host *" >> /home/mpi/.ssh/config \
	&& echo "port 2222" >> /home/mpi/.ssh/config

# Restrict the port range in-use so that they can be exposed by the worker
# containers.
ENV MPIR_CVAR_CH3_PORT_RANGE=24000:24100

RUN git clone https://github.com/IO500/io500.git \
	&& cd io500 && ./prepare.sh && make

RUN cd io500 && ./io500 --list > config-all.ini && ./io500 config-all.ini --dry-run
RUN sed -i 's/datadir = .\/datafiles/datadir = \/datafiles\/io500/g' io500/config-all.ini
RUN sed -i 's/posix.odirect =/posix.odirect = TRUE/g' io500/config-all.ini
RUN sed -i 's/verbosity = 1/verbosity = 0/g' io500/config-all.ini
RUN sed -i 's/resultdir = .\/results/resultdir = \/project\/results\//g' io500/config-all.ini
RUN cat io500/config-all.ini
