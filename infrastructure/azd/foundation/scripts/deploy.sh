#!/bin/bash
# Deploy AZD foundation (local ou pipeline)
# Compatível Windows via Git Bash ou WSL

# Define AZD environment
AZD_ENV="./env.template.json"

echo "Starting AZD deployment..."
azd up --environment-file $AZD_ENV

echo "AZD deployment finished."
