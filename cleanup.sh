#!/bin/bash

# Enhanced Cleanup Script for WAF-Protected Secure API Platform
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo -e "${BLUE}🧹 COMPREHENSIVE CLEANUP - WAF-Protected Secure API Platform${NC}"
echo "============================================================="

# Stop all port forwards first
info "Stopping all port-forward processes..."
pkill -f "kubectl port-forward" 2>/dev/null || true
log "Port forwards stopped"

# Uninstall Helm releases
info "Uninstalling Helm releases..."
helm uninstall user-service -n default 2>/dev/null && log "User service uninstalled" || warn "User service not found"
helm uninstall kong-gateway -n kong 2>/dev/null && log "Kong gateway uninstalled" || warn "Kong gateway not found"
helm uninstall waf-nginx -n default 2>/dev/null && log "WAF NGINX uninstalled" || warn "WAF NGINX not found"

# Clean up any CRDs that might be left
info "Cleaning up Kong CRDs..."
kubectl delete crd kongconsumers.configuration.konghq.com --ignore-not-found=true 2>/dev/null || true
kubectl delete crd kongplugins.configuration.konghq.com --ignore-not-found=true 2>/dev/null || true
kubectl delete crd kongingresss.configuration.konghq.com --ignore-not-found=true 2>/dev/null || true
kubectl delete crd kongclusterplugins.configuration.konghq.com --ignore-not-found=true 2>/dev/null || true

# Delete namespaces
info "Cleaning up namespaces..."
kubectl delete namespace kong --ignore-not-found=true 2>/dev/null && log "Kong namespace deleted" || warn "Kong namespace not found"

# Final verification
info "Verifying cleanup..."
remaining_pods=$(kubectl get pods -A | grep -E "(kong|nginx|user-service)" | wc -l || echo "0")
if [ "$remaining_pods" -eq 0 ]; then
    log "All WAF and platform pods cleaned up"
else
    warn "$remaining_pods platform/WAF pods still present"
fi

echo ""
echo -e "${GREEN}✅ WAF-PROTECTED PLATFORM CLEANUP COMPLETED!${NC}"
echo ""
echo -e "${GREEN}🚀 Ready for fresh WAF-protected deployment!${NC}"
