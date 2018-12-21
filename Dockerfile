
FROM debian:8

MAINTAINER Steve Flenniken

# This builds a build and test environment for metar.

RUN apt-get update \
  && apt-get -qy install curl libssl-dev build-essential gcc \
  python python3 xz-utils less git man sudo

# Set sudo so steve doesn't need to type in a password.
RUN mkdir -p /etc/sudoers.d
RUN echo "steve ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/steve
RUN chmod 440 /etc/sudoers.d/steve

# Create user steve with sudo permissions.
RUN adduser --disabled-password --gecos '' steve
RUN usermod -aG sudo steve
RUN echo 'steve:metar' | chpasswd

# Switch to user steve for following commands.

USER steve
WORKDIR /home/steve

# Install nim and nimpy module.
RUN curl -sSfLo init.sh https://nim-lang.org/choosenim/init.sh \
  && sed -i 's/need_tty=yes/need_tty=no/' init.sh \
  && bash init.sh \
  && rm init.sh \
  && export PATH=/home/steve/.nimble/bin:$PATH \
  && echo "export PATH=$PATH" >> .bashrc \
  && nimble install -y nimpy
 
# Add a couple of aliases.
RUN echo "alias ll='ls -l'" >> .bashrc \
  && echo "alias n='nimble'" >> .bashrc

RUN mkdir -p /home/steve/code/metarnim/
WORKDIR /home/steve/code/metarnim/

CMD /bin/bash
