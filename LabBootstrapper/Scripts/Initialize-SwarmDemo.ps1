$env:DOCKER_HOST="tcp://10.4.0.70:2375";

# Cleanup
docker restart swarm-master | Out-Null
Write-Host "Master restarted";
docker rm -vf portainer | Out-Null
Write-Host "Portainer deleted";

# Init
$swarmMasterIp = $(docker inspect --format '{{ .NetworkSettings.Networks.nat.IPAddress }}' swarm-master);
docker run -d --name=portainer --restart=always -p 80:9000 portainer/portainer:windows -H tcp://$($swarmMasterIp):2375 --swarm | Out-Null
Write-Host "Portainer started";

$env:DOCKER_HOST="tcp://10.4.0.70:3375";
Write-Host "Docker environment set: $env:DOCKER_HOST";