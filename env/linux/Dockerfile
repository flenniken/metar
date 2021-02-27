# Create a build and test environment for metar.

FROM debian:latest

MAINTAINER Steve Flenniken

RUN apt update \
  && apt -qy install curl libssl-dev build-essential gcc \
    python3 xz-utils less git man sudo tree \
    python3-pip python3-venv

# Set sudo so user steve doesn't need to type in a password.
RUN mkdir -p /etc/sudoers.d \
  && echo "steve ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/steve \
  && chmod 440 /etc/sudoers.d/steve

# Create user steve with sudo permissions.
RUN adduser --disabled-password --gecos '' steve \
  && usermod -aG sudo steve \
  && echo 'steve:metar' | chpasswd

# Switch to user steve for the following commands.

USER steve
WORKDIR /home/steve

# Install choosenim and the latest version of nim.
RUN curl -sSfLo init.sh https://nim-lang.org/choosenim/init.sh \
  && sed -i 's/need_tty=yes/need_tty=no/' init.sh \
  && bash init.sh \
  && rm init.sh \
  && export PATH=/home/steve/.nimble/bin:$PATH \
  && echo "export PATH=$PATH" >> .bashrc

# Add aliases.
RUN echo "alias ll='ls -l'" >> .bashrc \
  && echo "alias n='nimble'" >> .bashrc

# Put metar on the path.
RUN mkdir -p /home/steve/code/metar/ \
  && sudo ln -s /home/steve/code/metar/bin/linux/metar /usr/local/bin/metar

# Install nimpy.
RUN export PATH=/home/steve/.nimble/bin:$PATH \
  && nimble install -y nimpy@#c8ec14a # metarVersion*

RUN echo "PS1='\u:\w\$ '" >> .bashrc

# Create metarenv virtual environment.
ENV VIRTUAL_ENV=/home/steve/code/metar/env/linux/metarenv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
RUN python3 -m venv $VIRTUAL_ENV \
  && pip3 install wheel \
  && echo ". $VIRTUAL_ENV/bin/activate" >> .bashrc

WORKDIR /home/steve/code/metar/
CMD /bin/bash
