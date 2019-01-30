FROM nlknguyen/alpine-mpich

# Install packages necessary to build and run IOR.
RUN sudo apk add --no-cache autoconf automake git openssh

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
