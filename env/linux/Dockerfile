# Create a build and test environment for metar.

FROM debian:8

MAINTAINER Steve Flenniken

RUN apt-get update \
  && apt-get -qy install curl libssl-dev build-essential gcc \
  python python3 xz-utils less git man sudo tree \
  python-pip python3-pip

# Set sudo so user steve doesn't need to type in a password.
RUN mkdir -p /etc/sudoers.d
RUN echo "steve ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/steve
RUN chmod 440 /etc/sudoers.d/steve

# Create user steve with sudo permissions.
RUN adduser --disabled-password --gecos '' steve
RUN usermod -aG sudo steve
RUN echo 'steve:metar' | chpasswd

# Switch to user steve for the following commands.

USER steve
WORKDIR /home/steve

# Install nim and nimpy module.
RUN curl -sSfLo init.sh https://nim-lang.org/choosenim/init.sh \
  && sed -i 's/need_tty=yes/need_tty=no/' init.sh \
  && bash init.sh \
  && rm init.sh \
  && export PATH=/home/steve/.nimble/bin:$PATH \
  && echo "export PATH=$PATH" >> .bashrc

# Add aliases.
RUN echo "alias ll='ls -l'" >> .bashrc \
  && echo "alias n='nimble'" >> .bashrc

RUN mkdir -p /home/steve/code/metarnim/

# Put metar on the path.
RUN sudo ln -s /home/steve/code/metarnim/bin/linux/metar /usr/local/bin/metar

WORKDIR /home/steve/code/metarnim/
CMD /bin/bash

# Get the correct version of nim and nimpy.
# choosenim 0.20.0
# nimble install -y nimpy@#f6b6654
