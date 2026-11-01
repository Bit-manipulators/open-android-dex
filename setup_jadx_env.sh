#!/bin/bash
# Environment setup for REA JADX provider
# Source this file, then restart OpenCode

export REA_JADX_MCP_JAR="/home/amit/.local/share/rea/jadx/jadx-headless-mcp-0.7.1-all.jar"

echo "REA_JADX_MCP_JAR=$REA_JADX_MCP_JAR"
echo ""
echo "JADX JAR downloaded and ready at:"
echo "  $REA_JADX_MCP_JAR"
echo ""
echo "Next step: Restart OpenCode so the REA MCP server picks up this variable."
echo "Then you can reverse the Android APK at:"
echo "  non_tracked_folder/mobile_app/Android Dex.apk"
