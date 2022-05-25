# conjur-authn-k8s-rancher-demo

Update `./utils.sh` with variables values that match your environment!

**Deploy Rancher**
```sh
# Load context
. ./utils.sh

# Deploy Rancher
git clone https://github.com/rancher/quickstart.git
cd quickstart/aws
cp ./terraform.tfvars.example ./terraform.tfvars 
# TODO: update ./terraform.tfvars with your own values for aws_access_key, aws_secret_key, rancher_server_admin_password
terraform init
terraform apply
```

Use the output to get the URL to access the deployed Rancher cluster

**Deploy Conjur**, and **allowlist the Kubernetes authenticator**

```sh
# Load context
. ./utils.sh

# Deploy Conjur
git clone https://github.com/cyberark/conjur-quickstart.git

docker-compose pull

docker-compose run --no-deps --rm conjur data-key generate > ./tmp/data_key
export CONJUR_DATA_KEY="$(< ./tmp/data_key)"
export CONJUR_AUTHENTICATORS=${AUTHN_SERVICE_ID},authn
docker-compose up -d
docker-compose exec conjur conjurctl wait
docker-compose exec conjur conjurctl configuration show

# Create Conjur account
docker-compose exec conjur conjurctl account create ${CONJUR_ACCOUNT} > ./tmp/admin_data
cat ./tmp/admin_data | grep "API key" | tr -d '\r' | awk '{ print $5 }' > ./tmp/admin_api_key

# Setup Conjur-CLI as admin
docker-compose exec client conjur init -u conjur -a ${CONJUR_ACCOUNT}
docker-compose exec client conjur authn login -u admin -p "$(cat ./tmp/admin_api_key)"
```

Load Conjur policy to **Define Kubernetes Authenticator**
```sh
# Load context
. ./utils.sh

# Load authenticator policy
authn_service_id="conjur/${AUTHN_SERVICE_ID}" host_login=${TEST_APP_HOST} ./policy.yaml.sh > ./tmp/policy.yaml
cat ./tmp/policy.yaml | docker-compose exec -T client conjur policy load root -

# Loaded policy 'root'
# {
#   "created_roles": {
#     "rancherDemoAccount:host:demo-test-app-host": {
#       "id": "rancherDemoAccount:host:demo-test-app-host",
#       "api_key": "2k87e8x1eserjt33yykbcfmynk43b2chm83c0ggygyhhptd1jzepns"
#     }
#   },
#   "version": 1
# }
```
**Initialize Conjur CA** for the Kubernetes Authenticator
```sh
# Load context
. ./utils.sh

# Initialize the Conjur CA for the Kubernetes Authenticator
docker-compose exec -e CONJUR_ACCOUNT conjur rake authn_k8s:ca_init["conjur/${AUTHN_SERVICE_ID}"]
```

**Create a Rancher user** with appropriate permissions

1. Create user with minimal permissions
2. Create role (at project/cluster scope)
3. Add user to project/cluster and assign role
4. Create API key for user, scoped to
4. Gather connection details for the next steps

**Configure access to Kubernetes API** for the Kubernetes Authenticator

Now we have the necessary values to configure the Kubernetes authenticator:
+ Kubernetes service account token => Rancher API token
+ Kubernetes cluster API URL => Rancher server URL for specific Kubernetes cluster
+ Kubernetes cluster CA certificate => Rancher server CA certificate

```sh
# Load context
. ./utils.sh

# Example when values are in files
api_url=$(cat ./tmp/api-url)
ca_cert=$(cat ./tmp/ca-cert)
service_account_token=$(cat ./tmp/service-account-token)

api_url=
ca_cert=
service_account_token=

docker-compose exec client conjur variable values add conjur/${AUTHN_SERVICE_ID}/kubernetes/api-url "${api_url}"
docker-compose exec client conjur variable values add conjur/${AUTHN_SERVICE_ID}/kubernetes/ca-cert "${ca_cert}"
docker-compose exec client conjur variable values add conjur/${AUTHN_SERVICE_ID}/kubernetes/service-account-token "${service_account_token}"


docker-compose exec -e AUTHN_SERVICE_ID client bash -c '
function pp() {
    echo "$1: $(conjur variable value $1)"
    echo
}
echo "authenticator variables:"
echo ""
pp conjur/${AUTHN_SERVICE_ID}/kubernetes/service-account-token
pp conjur/${AUTHN_SERVICE_ID}/kubernetes/api-url
pp conjur/${AUTHN_SERVICE_ID}/kubernetes/ca-cert
'
```

Deploy app
```sh
# Load context
. ./utils.sh
 
# Get and store Conjur API SSL certificate
echo \
 | openssl s_client -showcerts -connect "$(ruby -e "require 'uri'; v = ARGV[0]; v = URI.parse(v); v = v.host + ':' + v.port.to_s; puts v" "${CONJUR_APPLIANCE_URL}")" 2>/dev/null \
 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' \
 > ./tmp/conjur-ca-cert.pem

# Deploy app with authn-k8s client sidecar
conjur_appliance_url="${CONJUR_APPLIANCE_URL}" \
conjur_configmap=$(kubectl create configmap conjur-config --from-file=ssl-certificate=./tmp/conjur-ca-cert.pem --dry-run=client -o yaml) \
conjur_authn_url="${CONJUR_APPLIANCE_URL}/$(ruby -e "require 'uri'; v = ARGV[0]; v = v.split('/', 2); v[1] = URI.encode_www_form_component(v[1]); v = v.join('/'); puts v" "${AUTHN_SERVICE_ID}")" \
conjur_account="${CONJUR_ACCOUNT}" \
host_login="${TEST_APP_HOST}" \
 ./app.yaml.sh > ./tmp/app.yaml
kubectl apply -f ./tmp/app.yaml
```

Connect using API token
```sh
# Load context
. ./utils.sh

token=$(kubectl exec deployment/test-app -c authenticator cat /run/conjur/access-token | tr -d '\r')
# token=$(docker-compose exec client conjur authn authenticate)

token=$(echo $token | base64 -w 0)
curl -k -v \
 -H 'Authorization: Token token="'${token}'"' \
 "${CONJUR_APPLIANCE_URL}/whoami" | jq
```
