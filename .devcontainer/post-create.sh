#!/bin/bash
set -e

echo "🔧 Configuring environment..."

# Configure CRC
echo "⚙️  Configuring CRC..."
crc config set consent-telemetry no
crc config set enable-cluster-monitoring false
crc config set memory 16384
crc config set cpus 6
crc config set disk-size 100

echo "✅ Configuration complete!"
