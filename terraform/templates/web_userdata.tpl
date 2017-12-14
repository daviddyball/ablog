#!/bin/bash
curl -fsSL https://get.docker.com/ | CHANNEL="stable" sh
sleep 10

docker pull daviddyball/ablog:latest
docker run -d -p 80:80 daviddyball/ablog:latest
