# OpenShift CRC Pull Secret Setup

CodeReady Containers (CRC) requires a pull secret from Red Hat to download OpenShift container images.

## Getting Your Pull Secret

1. **Visit the Red Hat Console:**
   - Go to: [https://console.redhat.com/openshift/create/local](https://console.redhat.com/openshift/create/local)

2. **Create a Free Account (if needed):**
   - Red Hat Developer accounts are free
   - No credit card required

3. **Download Pull Secret:**
   - Click "Download pull secret"
   - Save the file or copy the content

## Setting Up the Pull Secret

### Option 1: Use the Helper Script (Recommended)

```bash
./setup-crc-pull-secret.sh
```

Follow the prompts to either:
- Paste the pull secret content directly
- Provide the path to your downloaded pull secret file

### Option 2: Manual Setup

```bash
# Create the CRC directory if it doesn't exist
mkdir -p ~/.crc

# Copy your pull secret file
cp /path/to/your/pull-secret.json ~/.crc/pull-secret.json

# Or create it manually
cat > ~/.crc/pull-secret.json <<'EOF'
{paste your pull secret content here}
EOF
```

### Option 3: Let CRC Prompt You

Simply run:
```bash
crc start
```

CRC will detect that no pull secret is configured and prompt you to provide it.

## Starting CRC with Pull Secret

Once configured, CRC will automatically use the pull secret:

```bash
# Using cluster manager
./cluster-manager.sh start-all

# Or directly
crc start -p ~/.crc/pull-secret.json
```

## Troubleshooting

### Pull Secret Not Found

If you see errors about missing pull secret:

```bash
# Check if the file exists
ls -la ~/.crc/pull-secret.json

# If not, run the setup script
./setup-crc-pull-secret.sh
```

### Invalid Pull Secret

If CRC reports an invalid pull secret:

1. Verify the JSON format is correct
2. Download a fresh pull secret from Red Hat Console
3. Make sure you copied the entire content

### Permission Issues

```bash
# Ensure proper permissions
chmod 600 ~/.crc/pull-secret.json
```

## Additional Resources

- [Red Hat OpenShift Local Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_local/)
- [CRC GitHub Repository](https://github.com/crc-org/crc)
- [Red Hat Developer Program](https://developers.redhat.com/)
