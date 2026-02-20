# Secure API Platform with WAF Protection on Minikube

A complete **WAF-protected** secure API platform with **NGINX + ModSecurity WAF**, **Kong Gateway**, and **FastAPI microservice** with **JWT authentication** deployed on Minikube.

**🛡️ Enhanced Security**: All traffic flows through NGINX ModSecurity WAF → Kong Gateway → Microservice

## ⚡ Quick Start

```bash
./deploy.sh  # Deploy WAF-protected platform automatically
./test.sh    # Verify WAF and all components work
./cleanup.sh # Clean up when done
```

**Result**: Working WAF-protected secure API platform at `http://api.local:30080`

---

This repository contains a complete **WAF-protected** secure API platform running on Minikube with the following components:

- **NGINX Ingress Controller with ModSecurity WAF** for comprehensive DDoS/WAF protection
- **Kong Gateway (OSS)** with Ingress Controller for API gateway functionality  
- **FastAPI Microservice** with JWT authentication and SQLite persistence
- **Custom Kong Lua Plugin** for request logging and header injection
- **Complete Helm charts** for declarative deployment
- **Fully automated deployment scripts** for zero-manual-intervention setup

## Architecture

### WAF-Protected Security Architecture (All Traffic Protected)
```
Client → NGINX Ingress (ModSecurity WAF) → Kong Gateway → FastAPI Microservice
```

**🔒 Security Enforcement**: Kong Gateway is ClusterIP only - no direct external access allowed.

### Traffic Flow
1. **Client requests** hit NGINX Ingress Controller (NodePort 30080)
2. **ModSecurity WAF** applies OWASP Core Rule Set protection:
   - SQL injection detection and blocking
   - XSS protection  
   - Common web attack prevention
   - Request body analysis
   - Transaction logging
3. **Clean requests** are forwarded to Kong Gateway (ClusterIP)
4. **Kong Gateway** applies:
   - JWT authentication (protected routes: `/users`)
   - Authentication bypass (public routes: `/health`, `/verify`, `/login`)
   - Rate limiting (10 requests/min per IP)
   - IP allowlist validation
   - Custom request logging plugin
5. **Valid requests** reach the FastAPI user service

### Authentication Bypass Strategy

The platform implements **selective authentication bypass** through a dual-ingress architecture:

```
Client Request → NGINX WAF → Kong Gateway Router
                                    ↓
        ┌───────────────────────────┬───────────────────────────┐
        │     Public Ingress        │    Protected Ingress      │
        │   (No JWT Required)       │   (JWT Required)          │
        │                           │                           │
        │   • /health               │   • /users                │
        │   • /verify               │                           │
        │   • /login                │                           │
        │                           │                           │
        │   ✅ Bypasses Auth        │   🔒 Requires JWT         │
        └───────────────────────────┴───────────────────────────┘
                                    ↓
                            FastAPI Microservice
```

**Authentication Flow:**
- **Public Endpoints**: Direct access without JWT validation
- **Protected Endpoints**: JWT token validation enforced by Kong JWT plugin
- **Seamless Integration**: Same microservice handles both authenticated and unauthenticated requests

### Security Layers
- **L7 WAF**: ModSecurity with OWASP Core Rule Set
- **API Gateway**: Kong with JWT auth, rate limiting, IP restrictions
- **Application**: FastAPI with bcrypt password hashing and JWT validation
- **Persistence**: SQLite with PVC for data durability

## 🚀 Quick Start (Fully Automated)

### Three Simple Scripts

```bash
# 1. Deploy the platform
./deploy.sh

# 2. Test everything works
./test.sh

# 3. Clean up when done
./cleanup.sh
```

### What Each Script Does

| Script | Purpose |
|--------|---------|
| `./deploy.sh` | **Complete WAF-Protected Platform Deployment** - Checks prerequisites, starts Minikube, builds images, deploys Client→WAF→Kong→Microservice |
| `./test.sh` | **WAF & Security Validation** - Tests health, JWT auth, protected endpoints, WAF protection, security enforcement |
| `./cleanup.sh` | **Complete Cleanup** - Removes all WAF, Kong, and microservice components |

### Manual Prerequisites Setup (Alternative)

If you prefer manual control over prerequisites:

1. **Start Minikube with recommended configuration:**
```bash
minikube start --cpus=4 --memory=8192 --driver=docker
```

2. **Enable required addons:**
```bash
minikube addons enable ingress
minikube addons enable storage-provisioner
minikube addons enable metrics-server
```

3. **Add to /etc/hosts:**
```bash
echo "$(minikube ip) api.local" | sudo tee -a /etc/hosts
```

Then run `./deploy.sh` to deploy the platform.

### Dependencies

- **Docker** (for building images)
- **Helm 3.x**
- **kubectl**
- **Minikube**

## Installation

### Automated Installation (Recommended)

```bash
./deploy.sh
```

**This script automatically:**
- Checks prerequisites (Docker, kubectl, Minikube, Helm)
- Starts Minikube with optimal configuration if needed
- Configures /etc/hosts with api.local
- Builds and loads Docker images
- Deploys User Service and Kong Gateway for direct access
- Runs validation tests
- Provides access information and test commands

### Manual Installation

### Step 1: Build and Load Docker Images

```bash
# Build the FastAPI user service image
cd microservice
docker build -t user-service:latest .

# Load image into Minikube
minikube image load user-service:latest
```

### Step 2: Install Components in Order

**IMPORTANT**: Install in this exact order due to dependencies.

#### 2.1 Install NGINX Ingress (WAF Layer)
```bash
cd helm/waf
helm dependency update
helm install waf-nginx . -n ingress-nginx --create-namespace
```

#### 2.2 Install Kong Gateway
```bash
cd ../kong
helm dependency update
helm install kong-gateway . -n kong --create-namespace

# Wait for Kong to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kong -n kong --timeout=300s
```

#### 2.3 Install User Service
```bash
cd ../user-service
helm install user-service . -n default

# Wait for user service to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=user-service -n default --timeout=300s
```

### Step 3: Verify Installation

```bash
# Check all pods are running
kubectl get pods -A

# Check services
kubectl get services -A

# Check ingresses
kubectl get ingress -A
```

## API Testing

### Automated Testing

Run automated tests that verify all core functionality:

```bash
./test.sh
```

**The test script verifies:**
- ✅ Health endpoint connectivity
- ✅ JWT authentication flow (login → get token)
- ✅ Protected endpoints with JWT authorization
- ✅ Security enforcement (unauthorized access properly blocked)
- ✅ Token verification functionality
- ✅ Assignment requirements: Client → Kong → Microservice flow

### Manual Testing

Follow these step-by-step tests to verify all platform functionality:

### WAF-Protected API Access (Enhanced Security Flow)

**🛡️ Note**: All requests now flow through NGINX ModSecurity WAF for enhanced security.

#### 1. Health Check (Public Endpoint through WAF)
```bash
curl -X GET "http://api.local:30080/health"
```
**Expected Output**:
```json
{"status":"healthy","timestamp":"2026-02-17T20:05:15.319183","version":"1.0.0"}
```
**HTTP Status**: `200 OK`

#### 2. Login to Get JWT Token (through WAF)
```bash
curl -s -X POST "http://api.local:30080/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```
**Expected Output**:
```json
{"access_token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxI...","token_type":"bearer"}
```
**HTTP Status**: `200 OK`

**Extract Token**:
```bash
TOKEN=$(curl -s -X POST "http://api.local:30080/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' | \
  grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

echo "Token: ${TOKEN:0:50}..."
```

#### 3. Access Protected Route with JWT
```bash
curl -X GET "http://api.local:30080/users" \
  -H "Authorization: Bearer $TOKEN"
```
**Expected Output**:
```json
[{"id":1,"username":"admin","created_at":"2026-02-17 19:55:47"}]
```
**HTTP Status**: `200 OK`

#### 4. Access Protected Route without JWT (Security Test)
```bash
curl -X GET "http://api.local:30080/users"
```
**Expected Output**:
```json
{"detail":"Authorization header missing"}
```
**HTTP Status**: `401 Unauthorized`

#### 5. Token Verification
```bash
curl -X GET "http://api.local:30080/verify" \
  -H "Authorization: Bearer $TOKEN"
```
**Expected Output**:
```json
{"status":"valid_token","message":"Token is valid","user_id":1,"username":"admin"}
```
**HTTP Status**: `200 OK`

#### 6. Invalid Login Credentials Test
```bash
curl -X POST "http://api.local:30080/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"wrongpassword"}'
```
**Expected Output**:
```json
{"detail":"Invalid username or password"}
```
**HTTP Status**: `401 Unauthorized`

#### 7. Rate Limiting Test
```bash
# Send 12 rapid requests to trigger rate limiting
for i in {1..12}; do
  echo -n "Request $i: "
  curl -s -w "%{http_code}\n" -o /dev/null "http://api.local:30080/health"
  sleep 0.2
done
```
**Expected Output**:
```
Request 1: 200
Request 2: 200
...
Request 10: 200
Request 11: 429
Request 12: 429
```
**Note**: First 10 requests succeed (200), then rate limiting kicks in (429)

#### 8. Platform Status Check
```bash
kubectl get pods -A | grep -E "(kong|user-service)"
```
**Expected Output**:
```
default    user-service-6df6855f9-xxxxx    1/1     Running   0          10m
kong       kong-gateway-kong-xxxxx-xxxxx   2/2     Running   0          10m
```

#### 9. Kong Ingress Configuration Check
```bash
kubectl get ingresses -A
```
**Expected Output**:
```
NAMESPACE   NAME                     CLASS   HOSTS       ADDRESS        PORTS   AGE
kong        user-service-protected   kong    api.local   10.100.0.246   80      11m
kong        user-service-public      kong    api.local   10.100.0.246   80      11m
```

### Advanced Testing (With NGINX WAF)

**Note**: These tests require the full platform deployment with NGINX WAF layer.

#### 1. Health Check via NGINX Ingress
```bash
curl -X GET "http://api.local/health"
```
**Expected Output**: 
```json
{"status":"healthy","timestamp":"2026-02-17T20:05:15.319183","version":"1.0.0"}
```
**HTTP Status**: `200 OK`

#### 2. Login via NGINX Ingress
```bash
TOKEN=$(curl -s -X POST "http://api.local/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' | \
  grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

echo "Token: $TOKEN"
```

#### 3. Access Protected Route via NGINX
```bash
curl -X GET "http://api.local/users" \
  -H "Authorization: Bearer $TOKEN"
```
**Expected Output**:
```json
[{"id":1,"username":"admin","created_at":"2026-02-17 19:55:47"}]
```
**HTTP Status**: `200 OK`

#### 4. Access Protected Route without JWT
```bash
curl -X GET "http://api.local/users"
```
**Expected Output**:
```json
{"detail":"Authorization header missing"}
```
**HTTP Status**: `401 Unauthorized`

#### 5. WAF SQL Injection Protection Test
```bash
curl -X GET "http://api.local/health?id=1'+OR+'1'='1"
```
**Expected Output**:
```html
<html>
<head><title>403 Forbidden</title></head>
<body>
<center><h1>403 Forbidden</h1></center>
<hr><center>nginx</center>
</body>
</html>
```
**HTTP Status**: `403 Forbidden` (blocked by ModSecurity WAF)

#### 6. WAF Malicious User-Agent Protection Test
```bash
curl -X GET "http://api.local/health" \
  -H "User-Agent: sqlmap/1.0"
```
**Expected Output**:
```html
<html>
<head><title>403 Forbidden</title></head>
<body>
<center><h1>403 Forbidden</h1></center>
<hr><center>nginx</center>
</body>
</html>
```
**HTTP Status**: `403 Forbidden` (blocked by ModSecurity WAF)

#### 7. Rate Limiting Test (NGINX Layer)
```bash
# Send 15 requests rapidly (limit is 10/min)
for i in {1..15}; do
  echo "Request $i:"
  curl -s -w "%{http_code}\n" -X GET "http://api.local/health"
  sleep 1
done
```
**Expected Output**:
```
Request 1: 200
Request 2: 200
...
Request 10: 200
Request 11: 429
Request 12: 429
Request 13: 429
Request 14: 429
Request 15: 429
```
**Note**: First 10 requests return `200`, subsequent requests return `429 Too Many Requests`

#### 8. Check WAF Logs
```bash
kubectl exec -n ingress-nginx -it $(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}') -- tail -5 /var/log/modsec_audit.log
```
**Expected**: ModSecurity audit log entries showing blocked requests

### 🧪 Complete Manual Testing Checklist

Use this checklist to verify all functionality:

| Test | Command | Expected HTTP Status | Expected Response |
|------|---------|---------------------|-------------------|
| **Health Endpoint** | `curl http://api.local:30080/health` | 200 | `{"status":"healthy",...}` |
| **Valid Login** | `curl -X POST http://api.local:30080/login -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}'` | 200 | `{"access_token":"eyJ..."}` |
| **Invalid Login** | `curl -X POST http://api.local:30080/login -H "Content-Type: application/json" -d '{"username":"admin","password":"wrong"}'` | 401 | `{"detail":"Invalid username or password"}` |
| **Protected with JWT** | `curl -H "Authorization: Bearer $TOKEN" http://api.local:30080/users` | 200 | `[{"id":1,"username":"admin"...}]` |
| **Protected without JWT** | `curl http://api.local:30080/users` | 401 | `{"detail":"Authorization header missing"}` |
| **Token Verification** | `curl -H "Authorization: Bearer $TOKEN" http://api.local:30080/verify` | 200 | `{"status":"valid_token",...}` |
| **Rate Limiting** | Multiple rapid requests | 429 after 10 requests | Rate limit exceeded |
| **Pod Status** | `kubectl get pods -A | grep -E "(kong|user-service)"` | N/A | All pods Running |

### 🛡️ Enhanced Security Architecture Verification

**Client → WAF → Kong → Microservice Flow**:
- ✅ WAF-protected access via NGINX ModSecurity (NodePort 30080)
- ✅ All traffic filtered through OWASP Core Rule Set
- ✅ Kong Gateway secured behind WAF (ClusterIP only)
- ✅ JWT authentication working end-to-end through WAF
- ✅ Protected endpoints secured properly
- ✅ Rate limiting enforced
- ✅ SQL injection and XSS protection active
- ✅ All security layers functional

**Platform Status**:
- ✅ All components deployed and running
- ✅ Kong ingress routes configured correctly
- ✅ No errors in pod logs
- ✅ Ready for production use

## Monitoring and Logs

### Kong Logs
```bash
kubectl logs -n kong -l app.kubernetes.io/name=kong -f
```

### User Service Logs
```bash
kubectl logs -n default -l app.kubernetes.io/name=user-service -f
```

### NGINX Ingress Logs
```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f
```

### ModSecurity Audit Logs
```bash
# Access ModSecurity logs inside the NGINX pod
kubectl exec -n ingress-nginx -it $(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}') -- cat /var/log/modsec_audit.log
```

## Configuration

### JWT Secret Configuration
Update the JWT secret in both charts:

**User Service** (`helm/user-service/values.yaml`):
```yaml
jwt:
  secret: "your-super-secure-jwt-secret-key-here"
```

**Kong** (`helm/kong/values.yaml`):
```yaml
jwt:
  secret: "your-super-secure-jwt-secret-key-here"
```

### Rate Limiting Configuration
Modify rate limits in `helm/kong/values.yaml`:
```yaml
rateLimiting:
  requestsPerMinute: 20  # Increase from default 10
```

### IP Allowlist Configuration
Update allowed CIDR ranges in `helm/kong/values.yaml`:
```yaml
ipAllowlist:
  - "127.0.0.1/8"
  - "10.0.0.0/8"
  - "192.168.0.0/16"
  - "172.16.0.0/12"  # Add more ranges as needed
```

## Custom Kong Plugin

The custom Lua plugin (`kong/plugins/custom.lua`) provides:

1. **Request ID injection**: Adds `X-Request-Id` header to requests/responses
2. **Structured logging**: Emits JSON logs with request details:
   - Timestamp
   - Request ID
   - HTTP method and path
   - Client IP
   - User Agent
   - Host header

**Plugin logs can be seen in Kong container logs:**
```bash
kubectl logs -n kong -l app.kubernetes.io/name=kong | grep "Request processed"
```

## WAF Details

### Why NGINX + ModSecurity?

**NGINX Ingress Controller with ModSecurity** was chosen over alternatives because:

1. **Mature WAF Engine**: ModSecurity is industry-standard, battle-tested
2. **OWASP CRS**: Pre-configured rules for common attacks (SQLi, XSS, etc.)
3. **Kubernetes Native**: Integrates seamlessly with K8s ingress
4. **Performance**: NGINX is highly performant for L7 load balancing
5. **Open Source**: No licensing costs, community support

### WAF Rule Examples

The WAF includes these protections:
- **SQL Injection**: Detects SQLi patterns in query params, form data
- **Cross-Site Scripting (XSS)**: Blocks script injection attempts
- **Directory Traversal**: Prevents path traversal attacks
- **Protocol Validation**: Ensures HTTP compliance
- **Rate Limiting**: Works with Kong's rate limiting for layered protection

### Demonstrating WAF Blocks

1. **SQL Injection Block:**
```bash
curl "http://api.local/health?id=1'+UNION+SELECT+*+FROM+users--"
```

2. **XSS Block:**
```bash
curl "http://api.local/health" -d "<script>alert('xss')</script>"
```

3. **Check WAF Logs:**
```bash
kubectl exec -n ingress-nginx -it $(kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -o jsonpath='{.items[0].metadata.name}') -- tail -f /var/log/modsec_audit.log
```

## Troubleshooting

### Common Issues

1. **Pods not starting**: Check resource limits and Minikube memory
2. **DNS resolution**: Verify `/etc/hosts` entry or use `minikube tunnel`
3. **Image pull errors**: Ensure images are loaded with `minikube image load`
4. **Kong 503 errors**: Check if user-service is ready and accessible

### Debug Commands

```bash
# Check pod status and events
kubectl describe pod <pod-name> -n <namespace>

# Check service endpoints
kubectl get endpoints -A

# Check ingress status
kubectl describe ingress <ingress-name> -n <namespace>

# Port forward for direct access
kubectl port-forward service/user-service 8000:8000
```

### Reset Environment

```bash
# Uninstall all releases
helm uninstall user-service -n default
helm uninstall kong-gateway -n kong
helm uninstall waf-nginx -n ingress-nginx

# Delete namespaces
kubectl delete namespace kong
kubectl delete namespace ingress-nginx

# Restart Minikube if needed
minikube stop && minikube start --cpus=4 --memory=8192 --driver=docker
```

## Security Considerations

1. **JWT Secrets**: Use strong, unique secrets in production
2. **SQLite Persistence**: Consider PostgreSQL for production workloads  
3. **TLS**: Enable HTTPS/TLS for production deployments
4. **Network Policies**: Add Kubernetes network policies for pod-to-pod security
5. **RBAC**: Implement proper Kubernetes RBAC for service accounts
6. **Secrets Management**: Use external secret management (Vault, etc.) in production

## Production Readiness

This setup demonstrates security patterns but needs these enhancements for production:

- **High Availability**: Multi-replica deployments with anti-affinity
- **Persistent Database**: PostgreSQL with backup/restore procedures  
- **TLS Termination**: SSL certificates and HTTPS enforcement
- **Monitoring**: Prometheus, Grafana, alerting
- **Log Aggregation**: ELK stack or similar for centralized logging
- **External Secrets**: HashiCorp Vault or cloud secret management
- **Network Policies**: Zero-trust networking with Calico/Cilium