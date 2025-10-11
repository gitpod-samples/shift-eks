#!/bin/bash
# Verification script to check if all tools are installed

echo "🔍 Verifying installation..."
echo ""

check_command() {
    if command -v "$1" &> /dev/null; then
        echo "✅ $1 is installed: $(command -v $1)"
        if [ "$2" = "version" ]; then
            $1 version 2>&1 | head -n 1 | sed 's/^/   /'
        fi
    else
        echo "❌ $1 is NOT installed"
        return 1
    fi
}

echo "📦 Checking CLI tools:"
check_command kubectl version
check_command oc version
check_command crc version
check_command docker version
check_command aws version
check_command awslocal
check_command eksctl version
check_command python3 version
check_command pip3 version
check_command localstack

echo ""
echo "🐳 Checking Docker:"
docker ps 2>&1 | head -n 5

echo ""
echo "☸️  Checking Kubernetes contexts:"
kubectl config get-contexts 2>&1 || echo "No contexts configured yet"

echo ""
echo "🎯 Checking CRC cluster:"
crc status 2>&1 || echo "CRC not started yet"

echo ""
echo "🌩️  Checking LocalStack:"
docker ps | grep localstack || echo "LocalStack not running yet"

echo ""
echo "✅ Verification complete!"
