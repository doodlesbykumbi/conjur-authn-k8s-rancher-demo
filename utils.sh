export AUTHN_SERVICE_ID=authn-k8s/demo/rancher
export CONJUR_ACCOUNT=rancherDemoAccount
export TEST_APP_HOST=demo-test-app-host
export CONJUR_APPLIANCE_URL="https://path/to/conjur"
export KUBECONFIG=./tmp/config.yml
export COMPOSE_FILE=./conjur-quickstart/docker-compose.yml
mkdir -p ./tmp
