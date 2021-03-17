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
apigeeBackend="apigee-proxy-backend"

if [ -z "$1" ]
  then
    echo "Usage: Please provide the project ID where you have deployed Apigee and you would like to configure Cloud Armor."
    exit 1
fi

yourIP=$(curl -s "ifconfig.me")
echo "Project ID: " $project
echo "Your public IP: " $yourIP

gcloud config set project $project

echo "Creating security policy apigee-cloudarmor-demo..."
gcloud compute security-policies create apigee-cloudarmor-demo \
    --description "block bad traffic" \

# echo "Enabling adaptive protection..."
# gcloud alpha compute security-policies update apigee-cloudarmor-demo \
# 	--enable-layer7-ddos-defense

# echo "Enabling adaptive protection..."
# gcloud alpha compute security-policies update apigee-cloudarmor-demo \
# 	--enable-ml

echo "Creating security rule to allow traffic from $yourIP..."
gcloud compute security-policies rules create 1000 \
    --security-policy apigee-cloudarmor-demo \
    --description "allow traffic from $yourIP" \
    --src-ip-ranges  "${yourIP}/32" \
    --action "allow"

echo "Creating security rule to prevent SQL injection attacks..."
gcloud compute security-policies rules create 1001 \
    --security-policy apigee-cloudarmor-demo \
    --expression "evaluatePreconfiguredExpr('sqli-stable')" \
    --action "deny-403"

echo "Applying security policy to target backend apigee-proxy-backend..."
gcloud compute backend-services update $apigeeBackend \
    --security-policy apigee-cloudarmor-demo --global

echo "Adding Apigee backend as origin to Cloud CDN..."
gcloud compute backend-services update $apigeeBackend \
    --enable-cdn \
    --cache-mode="USE_ORIGIN_HEADERS" \
    --global