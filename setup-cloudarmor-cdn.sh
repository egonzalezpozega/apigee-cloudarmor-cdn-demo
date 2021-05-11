#!/bin/bash
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

project=$1

if [ -z "$1" ]
  then
    echo "Usage: Please provide the project ID where you have deployed Apigee and you would like to configure Cloud Armor."
    exit 1
fi

if [ -z "$2" ]
  then
    apigeeBackend="apigee-proxy-backend"
  else
    apigeeBackend=$2
fi

yourIP=$(curl -s "ifconfig.me")
echo "Project ID: " $project
echo "Your public IP: " $yourIP

gcloud config set project $project

existingPolicy=$(gcloud compute security-policies list | grep 'apigee-cloudarmor-demo' | awk '{print $1}')

if [ -z "$existingPolicy" ]; then

    echo "Creating security policy apigee-cloudarmor-demo..."
    gcloud compute security-policies create apigee-cloudarmor-demo \
        --description "block bad traffic" \

    echo "Updating default security rule to block all traffic..."
    gcloud compute security-policies rules update 2147483647 \
    	--security-policy apigee-cloudarmor-demo \
    	--description "block all traffic" \
    	--src-ip-ranges "*" \
    	--action "deny-403"

    echo "Creating security rule to prevent SQL injection attacks..."
    gcloud compute security-policies rules create 1000 \
        --security-policy apigee-cloudarmor-demo \
        --expression "evaluatePreconfiguredExpr('sqli-stable')" \
        --action "deny-403"

    echo "Creating security rule to allow traffic from $yourIP..."
      gcloud compute security-policies rules create 1001 \
        --security-policy apigee-cloudarmor-demo \
        --description "allow traffic from $yourIP" \
        --src-ip-ranges  "${yourIP}/32" \
        --action "allow"

    echo "Applying security policy to target backend $apigeeBackend..."
    gcloud compute backend-services update $apigeeBackend \
        --security-policy apigee-cloudarmor-demo --global

    echo "Adding Apigee backend as origin to Cloud CDN..."
    gcloud compute backend-services update $apigeeBackend \
        --enable-cdn \
        --cache-mode="USE_ORIGIN_HEADERS" \
        --global

  RESULT=$?
  if [ $RESULT -ne 0 ]; then
    echo "Failed to create security rule to allow traffic from your IP..."
    exit 1
  fi
else
  echo "A security rule to allow traffic from your IP already exists...updating rule to your current IP $yourIP ..."
  gcloud compute security-policies rules update 1001 \
    --security-policy apigee-cloudarmor-demo \
    --description "allow traffic from $yourIP" \
    --src-ip-ranges  "${yourIP}/32" \
    --action "allow"
fi