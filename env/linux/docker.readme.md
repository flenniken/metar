
Metar Development Machine
=========================

Note: See "n tasks" for the equivalent docker tasks.

Development machine for building metar on Debian 8.

Build Machine
-------------

To see whether the metar-machine image exists run:

```
docker images
```

To build the metar-machine image run the build command:

```
cd ~/code/metarnim
./build-docker-env.sh
```

Run Container
-------------

The metar-machine container is called metar. You can see whether
it is running with:

```
docker ps
```

If it does not exist, you can create it with the following command.
The metar Mac folder is mounted so you can see it files inside the
container.

```
docker rm metar
docker run -v /Users/steve/code/metarnim:/home/steve/code/metarnim \
--name=metar -it metar-machine
```

If the metar machine is running you can attach to it with:

```
docker attach metar
```

If the metar machine is not running but it exists, you can connect to
it with:

```
docker start metar
```

Stop Container
--------------

To stop a running container:

```
docker stop metar
```

Detach From Container
---------------------

To detach from the running container type two keys:

```
ctrl+p, ctrl+q
```
