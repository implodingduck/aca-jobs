docker stop ondemand
docker rm ondemand
docker build -t ondemand .
docker run --env-file .env --name ondemand ondemand