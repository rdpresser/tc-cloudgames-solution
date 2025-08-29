#!/bin/bash
# Deploy AZD Foundation (Container App Environment + Key Vault)
# Compatível Linux / Mac / Git Bash / WSL
# -------------------------------------------------------

# Caminho para o env.json
AZD_ENV="./env.json"

# Verifica se o arquivo existe
if [ ! -f "$AZD_ENV" ]; then
    echo "❌ Environment file $AZD_ENV não encontrado. Gere a partir do env.template.json ou do pipeline."
    exit 1
fi

echo "🚀 Iniciando deploy AZD usando $AZD_ENV ..."

# Executa o deploy
azd up --environment-file "$AZD_ENV" --verbose

echo "✅ Deploy AZD finalizado."
