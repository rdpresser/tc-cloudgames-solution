#!/bin/bash
# Destroy AZD resources
AZD_ENV="./env.template.json"

echo "Destroying AZD resources..."
azd down --environment-file $AZD_ENV

echo "AZD resources destroyed."
