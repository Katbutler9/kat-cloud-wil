#!/bin/bash

# This script sets up the GitHub CLI authentication for the current user.
set -e

source .env
unset GH_TOKEN GITHUB_TOKEN
gh auth logout --hostname github.com || true
echo "$ADMIN_TOKEN" | gh auth login --with-token --hostname github.com

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

SP_NAME="gh-actions-sp"
APP_ID=$(az ad sp list --display-name "$SP_NAME" --query "[0].appId" -o tsv || true)

if [[ -z "$APP_ID" ]]; then
  echo "🆕 Creating new service principal: $SP_NAME"
  APP_ID=$(az ad app create --display-name "$SP_NAME" --query appId -o tsv)
  az ad sp create --id "$APP_ID"
else
  echo "✅ Found existing service principal: $APP_ID"
fi

az role assignment create \
  --assignee "$APP_ID" \
  --role Contributor \
  --scope "/subscriptions/$SUBSCRIPTION_ID" || echo "ℹ️ Contributor role may already be assigned."

  CLIENT_SECRET=$(az ad app credential reset   --id "$APP_ID"   --append   --query password -o tsv)

  LOCATION="australiaeast"
RG_NAME="lab5-rg"

echo "export LOCATION=$LOCATION" >> .env # store LOCATION in .env
echo "RG_NAME=$RG_NAME" >> .env # store RG_NAME in .env

az provider register --namespace Microsoft.Web

az group create --name "$RG_NAME" --location "$LOCATION"

AZURE_CREDENTIALS=$(cat <<EOF
{
  "clientId": "$APP_ID",
  "clientSecret": "$CLIENT_SECRET",
  "subscriptionId": "$SUBSCRIPTION_ID",
  "tenantId": "$TENANT_ID",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
EOF
)

APP_NAME="lab5app$random" # generate a unique app name

echo "export APP_NAME=$APP_NAME" >> .env # store APP_NAME in .env

echo "$APP_NAME" | gh secret set APP_NAME
echo "$AZURE_CREDENTIALS" | gh secret set AZURE_CREDENTIALS
