#!/bin/bash

# Run the metar container.

container=metar-container
image=metar-image

docker ps | grep $container
if [ $? == 0 ]; then
  echo "Attaching to the running container."
  docker attach $container
else
  docker ps -a | grep $container
  if [ $? == 0 ]; then
    echo "Starting the existing container."
    docker start $container
    docker attach $container
  else
    echo "Running a new container."
    # xpictures is a link to external folder of images.

    docker run -v /Users/steve/code/metar:/home/steve/code/metar \
           -v /Users/steve/xpictures:/home/steve/xpictures \
      --name=metar-container -it metar-image
  fi
fi
