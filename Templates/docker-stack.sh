#!/bin/bash
# Docker Swarm Stack Deployment Script
# Run this on the Manager node
echo "Creating docker-stack.yml..."
cat > docker-stack.yml << 'EOF'
version: "3.8"
services:
  web:
    image: 542478884453.dkr.ecr.eu-west-1.amazonaws.com/ds-demo-web:v1    # ← NY: Din MVC-app från ECR
    deploy:
      replicas: 3
      restart_policy:
        condition: on-failure
      update_config:
        parallelism: 1
        delay: 5s
    ports:
      - "80:80"
    networks: [webnet]
  viz:
    image: dockersamples/visualizer:stable
    deploy:
      placement:
        constraints: [node.role == manager]
    ports:
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks: [webnet]
networks:
  webnet:
    driver: overlay
EOF
echo "✓ docker-stack.yml created"
echo ""
echo "Deploying stack 'myapp'..."
sudo docker stack deploy -c docker-stack.yml myapp
echo ""
echo "Waiting for services to start..."
sleep 10
echo ""
echo "=== Stack Status ==="
sudo docker stack ls
echo ""
echo "=== Services ==="
sudo docker service ls
echo ""
echo "=== Web Service Details ==="
sudo docker service ps myapp_web
echo ""
echo "=== Visualizer Service Details ==="
sudo docker service ps myapp_viz
echo ""
echo "✓ Deployment complete!"