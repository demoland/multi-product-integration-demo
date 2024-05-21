#!/bin/bash
# set -x

HAVE_HCP=$(which hcp |grep "/usr/local/bin/hcp" >/dev/null; echo $?)
if [[ $HAVE_HCP -ne 0 ]]; then
  echo "HCP CLI is not installed. Please install it from https://learn.hashicorp.com/tutorials/hcp/get-started-install-cli"
  exit 1
fi

TOKEN=$(cat ~/.terraform.d/credentials.tfrc.json | jq -r '.credentials."app.terraform.io".token')

WORKSPACE_NAME=2_hcp-clusters
ORGANIZATION=demo-land
PROJECT=hashistack

HCP_CLIENT_ID=$(op read op://private/hcp-cloud/client-id)
HCP_CLIENT_SECRET=$(op read op://private/hcp-cloud/client-secret)
HCP_ORG_ID=$(hcp organizations list --format=json |jq -r '.[].id')
HCP_PROJECT_ID=$(hcp projects list --format=json |jq -r '.[]|select(.name == "hashistack").id')

# Get the HCP Access Token using your HCP Client ID and Secret:
HCP_ACCESS_TOKEN=$(curl -s --location "https://auth.idp.hashicorp.com/oauth2/token" \
--header "Content-Type: application/x-www-form-urlencoded" \
--data-urlencode "client_id=$HCP_CLIENT_ID" \
--data-urlencode "client_secret=$HCP_CLIENT_SECRET" \
--data-urlencode "grant_type=client_credentials" \
--data-urlencode "audience=https://api.hashicorp.cloud" | jq -r .access_token)
# Get the Consul Root Token:
# CONSUL_CLUSTER_NAME="${ORGANIZATION}-consul-cluster"
# set -x
# curl -s "https://api.cloud.hashicorp.com/consul/2020-04-13/organizations/$HCP_ORG_ID/projects/$HCP_PROJECT_ID/clusters/$CONSUL_CLUSTER_NAME/master-acl-tokens?location.region.provider=aws&location.region.region=us-west-2" \
# --header "authorization: Bearer $HCP_ACCESS_TOKEN"


PROJECT_ID=$(curl -s\
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  https://app.terraform.io/api/v2/organizations/${ORGANIZATION}/projects | jq -r ".data[]|select(.attributes.name == \"${PROJECT}\" ).id")

WORKSPACE_ID=$(curl -s \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  https://app.terraform.io/api/v2/organizations/demo-land/workspaces |jq -r '.data[] | select(.attributes.name == "2_hcp-clusters").id')

# Get Statefile versions: 
HCP_CURRENT_SF_ID=$(curl -s -X GET \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  https://app.terraform.io/api/v2/workspaces/${WORKSPACE_ID}/current-state-version |jq -r '.data.id')

# Get the BOUNDARY Address:
export BOUNDARY_ADDR=$(curl -s -X GET \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  https://app.terraform.io/api/v2/state-versions/${HCP_CURRENT_SF_ID}/outputs |jq -r '.data[]|select(.attributes.name == "boundary_public_endpoint").attributes.value')

echo "export BOUNDARY_ADDR=${BOUNDARY_ADDR}"

#Get the Vault Address:
export VAULT_ADDR=$(curl -s -X GET \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  https://app.terraform.io/api/v2/state-versions/${HCP_CURRENT_SF_ID}/outputs |jq -r '.data[]|select(.attributes.name == "vault_public_endpoint").attributes.value')

echo "export VAULT_ADDR=${VAULT_ADDR}"

# Get the Vault Token:
VAULT_CLUSTER_NAME=${ORGANIZATION}-vault-cluster

export VAULT_TOKEN=$(curl -s "https://api.cloud.hashicorp.com/vault/2020-11-25/organizations/$HCP_ORG_ID/projects/$HCP_PROJECT_ID/clusters/$VAULT_CLUSTER_NAME/admintoken?location.region.provider=aws&location.region.region=us-west-2" \
--header "authorization: Bearer $HCP_ACCESS_TOKEN" | jq '.token')

echo "export VAULT_TOKEN=${VAULT_TOKEN}"

#Get the Consul Address:
export CONSUL_HTTP_ADDR=$(curl -s -X GET \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  https://app.terraform.io/api/v2/state-versions/${HCP_CURRENT_SF_ID}/outputs |jq -r '.data[]|select(.attributes.name == "consul_public_endpoint").attributes.value')

echo "export CONSUL_HTTP_ADDR=${CONSUL_HTTP_ADDR}"


# Get the Consul Root Token:
# CONSUL_CLUSTER_NAME="${ORGANIZATION}-consul-cluster"
# export CONSUL_HTTP_TOKEN=$(curl -s "https://api.cloud.hashicorp.com/vault/2020-11-25/organizations/$HCP_ORG_ID/projects/$HCP_PROJECT_ID/clusters/$CONSUL_CLUSTER_NAME/admintoken?location.region.provider=aws&location.region.region=us-west-2" \
# --header "authorization: Bearer $HCP_ACCESS_TOKEN" | jq '.token')

# Get the Workspace ID that holds the Nomad Cluster endpoint output : 
export NOMAD_WORKSPACE_ID=$(curl -s \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  https://app.terraform.io/api/v2/organizations/demo-land/workspaces |jq -r '.data[] | select(.attributes.name == "5_nomad-cluster").id')

# Get Nomad Statefile current version: 
export NOMAD_CURRENT_SF_ID=$(curl -s -X GET \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  https://app.terraform.io/api/v2/workspaces/${NOMAD_WORKSPACE_ID}/current-state-version |jq -r '.data.id')

# Get the Nomad Address:
export NOMAD_ADDR=$(curl -s -X GET \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  https://app.terraform.io/api/v2/state-versions/${NOMAD_CURRENT_SF_ID}/outputs |jq -r '.data[]|select(.attributes.name == "nomad_public_endpoint").attributes.value')

echo "export NOMAD_ADDR=${NOMAD_ADDR}"

#
