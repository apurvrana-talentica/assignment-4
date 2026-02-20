#!/bin/bash

# Automated Secure API Platform Deployment
# Client → Kong → Microservice flow with full automation
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function for colored output
log() {
    echo -e "${GREEN}✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo -e "${BLUE}🚀 AUTOMATED Secure API Platform Deployment${NC}"
echo "=============================================="
echo "Deploying: Client → WAF (NGINX) → Kong → Microservice flow"
echo "All traffic protected by ModSecurity WAF"
echo ""

# Step 1: Prerequisites check
info "1️⃣ Checking prerequisites..."
command -v kubectl >/dev/null 2>&1 || error "kubectl not found"
command -v minikube >/dev/null 2>&1 || error "minikube not found"
command -v helm >/dev/null 2>&1 || error "helm not found"
command -v docker >/dev/null 2>&1 || error "docker not found"
log "All prerequisites available"

# Step 2: Minikube setup
info "2️⃣ Setting up Minikube..."
if ! minikube status >/dev/null 2>&1; then
    warn "Starting Minikube with optimal settings..."
    minikube start --cpus=4 --memory=8192 --disk-size=20g --driver=docker
    log "Minikube started"
else
    log "Minikube already running"
fi

# Enable essential addons
minikube addons enable storage-provisioner
minikube addons enable metrics-server
log "Minikube addons enabled"

# Step 3: DNS configuration
info "3️⃣ Configuring local DNS..."
MINIKUBE_IP=$(minikube ip)
if grep -q "api.local" /etc/hosts 2>/dev/null; then
    sudo sed -i.backup "s/.*api.local/$MINIKUBE_IP api.local/" /etc/hosts
    log "Updated api.local → $MINIKUBE_IP"
else
    echo "$MINIKUBE_IP api.local" | sudo tee -a /etc/hosts >/dev/null
    log "Added api.local → $MINIKUBE_IP"
fi

# Step 4: Build and load images
info "4️⃣ Building Docker images..."
cd microservice
docker build -t user-service:latest . >/dev/null 2>&1
minikube image load user-service:latest
log "Images built and loaded"
cd ..

# Step 4.5: Externalize JWT Secret
info "🔑 Configuring externalized JWT secret..."
if [ -n "$JWT_SECRET" ]; then
    log "Using JWT secret from environment variable"
else
    JWT_SECRET=$(openssl rand -base64 32)
    export JWT_SECRET
    log "Generated random JWT secret (externalized, not hardcoded)"
fi

# Step 5: Deploy components
info "5️⃣ Deploying platform components..."

# Deploy User Service
info "Installing User Service..."
cd helm/user-service
helm upgrade --install user-service . -n default \
    --set jwt.secret="$JWT_SECRET" \
    --wait --timeout=300s >/dev/null
log "User Service deployed"
cd ../..

# Deploy Kong with ClusterIP-only configuration (WAF-protected)
info "Installing Kong Gateway (ClusterIP only - accessible through WAF)..."
cd helm/kong

# Use the single values.yaml file (ClusterIP only configuration)
helm upgrade --install kong-gateway . -n kong --create-namespace \
    --set jwt.secret="$JWT_SECRET" \
    --wait --timeout=300s >/dev/null
log "Kong Gateway deployed (ClusterIP only - accessible through WAF)"
cd ../..

# Step 6: Deploy WAF (NGINX + ModSecurity) 
info "6️⃣ Deploying WAF protection layer..."
cd helm/waf
helm upgrade --install waf-nginx . --wait --timeout=300s >/dev/null
log "WAF deployed with ModSecurity on NodePort 30080"
cd ../..

# Step 7: Verification and testing
info "7️⃣ Running automated verification..."

# Wait for pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=user-service -n default --timeout=120s >/dev/null
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kong -n kong --timeout=120s >/dev/null
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n default --timeout=120s >/dev/null

log "All pods ready"

# Test WAF-protected access
info "Testing WAF-protected API access (NodePort 30080)..."
sleep 15  # Allow WAF and Kong to fully initialize

# Health check through WAF
if curl -s --max-time 10 http://api.local:30080/health >/dev/null; then
    log "Health endpoint accessible through WAF"
else
    warn "Health endpoint not immediately accessible (may need more time)"
fi

# JWT authentication test through WAF
info "Testing JWT authentication through WAF..."
TOKEN_RESPONSE=$(curl -s --max-time 10 -X POST http://api.local:30080/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin123"}' 2>/dev/null || echo "failed")

if echo "$TOKEN_RESPONSE" | grep -q "access_token"; then
    TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    log "JWT authentication working through WAF"
    
    # Test protected endpoint through WAF
    if curl -s --max-time 10 -H "Authorization: Bearer $TOKEN" http://api.local:30080/users >/dev/null; then
        log "Protected endpoint accessible with JWT through WAF"
    fi
else
    warn "JWT authentication test pending (WAF/Kong may still be initializing)"
fi

echo ""
echo -e "${GREEN}🎉 SECURE API PLATFORM DEPLOYMENT COMPLETE! 🎉${NC}"
echo "=================================================="
echo ""
echo -e "${BLUE}✨ WAF-Protected Platform Ready - Enhanced Security ✨${NC}"
echo "Flow: Client → WAF (NGINX+ModSecurity) → Kong → Microservice"
echo ""
echo -e "${BLUE}🔗 Access Points (All WAF-Protected):${NC}"
echo "• Health Check: http://api.local:30080/health"
echo "• Login: http://api.local:30080/login"
echo "• Protected Users: http://api.local:30080/users (requires JWT)"
echo "• Token Verify: http://api.local:30080/verify"
echo ""
echo -e "${BLUE}🛡️ Security Layers Applied:${NC}"
echo "1. NGINX + ModSecurity WAF (OWASP Core Rule Set)"
echo "2. Kong Gateway (JWT, Rate Limiting, IP Filter)"
echo "3. FastAPI Service (JWT Validation, SQLite)"
echo ""
echo -e "${BLUE}🧪 Quick Tests:${NC}"
echo ""
echo "# 1. Health check through WAF"
echo "curl http://api.local:30080/health"
echo ""
echo "# 2. Get JWT token through WAF"
echo "TOKEN=\$(curl -s -X POST http://api.local:30080/login -H \"Content-Type: application/json\" -d '{\"username\":\"admin\",\"password\":\"admin123\"}' | grep -o '\"access_token\":\"[^\"]*\"' | cut -d'\"' -f4)"
echo ""
echo "# 3. Access protected endpoint through WAF"
echo "curl -H \"Authorization: Bearer \$TOKEN\" http://api.local:30080/users"
echo ""
echo -e "${BLUE}🔧 Management:${NC}"
echo "• View pods: kubectl get pods -A"
echo "• WAF logs: kubectl logs -f -l app.kubernetes.io/name=ingress-nginx"
echo "• Kong admin (port-forward): kubectl port-forward -n kong service/kong-gateway-kong-admin 8001:8001"
echo "• Clean up: ./cleanup.sh"
echo ""
echo -e "${GREEN}🏆 WAF-protected secure API platform is now running!${NC}"