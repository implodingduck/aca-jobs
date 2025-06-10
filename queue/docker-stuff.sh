docker stop queue
docker rm queue
docker build -t queue .
docker run --env-file .env --name queue queue