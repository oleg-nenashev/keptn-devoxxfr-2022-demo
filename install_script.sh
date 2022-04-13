#!/usr/bin/env bash

# this function is called when Ctrl-C is sent
function trap_ctrlc ()
{
    # perform cleanup here
    echo "Preventing ungraceful shutdown. Please don't use Ctrl+C. Wait until the script has finished and then type: exit"
}

# initialise trap to call trap_ctrlc function
# when signal 2 (SIGINT) is received
trap "trap_ctrlc" 2

# Set global variables
KIND_KEPTN_VERSION="0.14.1 - Devoxx FR Demo"
KEPTN_VERSION=0.14.1
JOB_EXECUTOR_SERVICE_VERSION=0.1.8
PROMETHEUS_SERVICE_VERSION=0.7.3

# This is the install script that is included in 'docker build' and executes on 'docker run'
echo "------------------------------------------------------------------------"
echo " Keptn Installer $KIND_KEPTN_VERSION"
echo " DO NOT PRESS CONTROL + C to exit..."
echo " ONLY use 'exit'" 
echo " If things fail, LET THEM, then when you get the bash prompt, type: exit"
echo " This is required to gracefully cleanup docker and k3d before closing."
echo ""
echo " Installer will continue automatically in 10 seconds"
echo "------------------------------------------------------------------------"
sleep 10

echo "-- Installing Versions --"
echo "Keptn: $KEPTN_VERSION"
echo "Job Executor Service: $JOB_EXECUTOR_SERVICE_VERSION"

echo "-- Bringing up a cluster --"
k3d cluster create mykeptn --config=/root/k3dconfig.yaml --wait

# Add sleep before continuing to prevent misleading error
sleep 10

echo "-- Waiting for all resources to be ready (timeout 2 mins) --"
kubectl wait --for=condition=ready pods --all --all-namespaces --timeout=2m

echo "-- Installing Prometheus"
kubectl create namespace monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/prometheus --namespace monitoring
# Times out kubectl port-forward svc/prometheus-server 8080:80 -n monitoring

echo "-- Installing Keptn via Helm. This will take a few minutes (timeout 10mins) --"
extra_params=""


helm install keptn https://github.com/keptn/keptn/releases/download/$KEPTN_VERSION/keptn-$KEPTN_VERSION.tgz $extra_params \
  -n keptn --create-namespace \
  --wait --timeout=10m \
  --set=control-plane.apiGatewayNginx.type=LoadBalancer \
  --set=control-plane.bridge.versionCheck.enabled=false

echo "-- Deleting bridge credentials for demo mode (no login required) --"
kubectl -n keptn delete secret bridge-credentials --ignore-not-found=true

echo "-- Restart Keptn Bridge to load new settings --"
kubectl -n keptn delete pods --selector=app.kubernetes.io/name=bridge --wait

echo "-- Installing Job Executor Service --"
helm install -n keptn job-executor-service https://github.com/keptn-contrib/job-executor-service/releases/download/$JOB_EXECUTOR_SERVICE_VERSION/job-executor-service-$JOB_EXECUTOR_SERVICE_VERSION.tgz

echo "-- Install Prometheus service"
helm upgrade --install -n keptn prometheus-service https://github.com/keptn-contrib/prometheus-service/releases/download/${PROMETHEUS_SERVICE_VERSION}/prometheus-service-${PROMETHEUS_SERVICE_VERSION}.tgz --reuse-values
kubectl -n monitoring apply -f https://raw.githubusercontent.com/keptn-contrib/prometheus-service/${PROMETHEUS_SERVICE_VERSION}/deploy/role.yaml
helm upgrade -n keptn prometheus-service https://github.com/keptn-contrib/prometheus-service/releases/download/<VERSION>/prometheus-service-${PROMETHEUS_SERVICE_VERSION}.tgz --reuse-values --set=prometheus.namespace="monitoring",prometheus.endpoint="http://prometheus-server.monitoring.svc.cluster.local:8",prometheus.namespace_am="monitoring"
keptn configure monitoring prometheus --project=sockshop --service=carts

echo "-- Wait for all pods in Keptn namespace to signal ready. (timeout 2 mins) --"
kubectl -n keptn wait --for=condition=ready pods --all --timeout=2m

# host.docker.internal is a special address that routes to the host machine (eg. laptop)
echo "-- Authenticating keptn CLI --"
keptn auth --endpoint=http://host.docker.internal --api-token=$(kubectl get secret keptn-api-token -n keptn -ojsonpath={.data.keptn-api-token} | base64 -d)

echo "-- Create Keptn Hello World Project --"
wget https://raw.githubusercontent.com/agardnerIT/thekindkeptn/main/shipyard.yaml
keptn create project helloworld --shipyard=shipyard.yaml
keptn create service demoservice --project=helloworld

echo "-- Create the Podtato Head Demo Project --"
keptn create project podtatohead --shipyard=/root/sample-project/demo/shipyard.yaml
keptn create service helloservice --project=podtatohead


echo "-- Applying Job Config YAML File. This is the file the job-exector-service looks at to ultimately runs the helloworld container) --"
wget https://raw.githubusercontent.com/agardnerIT/thekindkeptn/main/jobconfig.yaml
keptn add-resource --project=helloworld --service=demoservice --stage=demo --resource=jobconfig.yaml --resourceUri=job/config.yaml

echo "-- Downloading Sample Cloud Event JSON File --"
wget https://raw.githubusercontent.com/agardnerIT/thekindkeptn/main/helloevent.cloudevent.json

echo "-- Triggering first Keptn Sequence --"
keptn send event -f helloevent.cloudevent.json
echo ========================================================
echo Keptn is now running
echo Visit: http://localhost from your host machine
echo Type 'exit' to exit the docker container
echo ========================================================

# Start up a bash shell to try out thekindkeptn
cd
/bin/bash

# Clean up cluster after exit from shell
k3d cluster delete mykeptn
