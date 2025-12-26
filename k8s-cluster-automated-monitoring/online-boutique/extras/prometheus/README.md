# Prometheus Monitoring for Online Boutique

This directory contains Prometheus monitoring configurations for the Online Boutique microservices application.

## Files

- **pod-rules.yaml**: Pod-based alert rules for microservice uptime monitoring (RECOMMENDED)
- **probes.yaml**: Blackbox exporter probes (HTTP only - not suitable for gRPC services)
- **rules.yaml**: Original blackbox-based rules (deprecated - use pod-rules.yaml instead)
- **alertmanagerconfig.yaml**: Slack notification configuration for Alertmanager
- **values.yaml**: Helm values for prometheus-community/kube-prometheus-stack

## Important: gRPC vs HTTP Services

Most Online Boutique services use **gRPC**, not HTTP:
- ✅ **HTTP**: frontend (works with blackbox probes)
- ❌ **gRPC**: cartservice, paymentservice, shippingservice, emailservice, etc. (fails with HTTP blackbox probes)

**Solution**: Use `pod-rules.yaml` which monitors Kubernetes pod availability instead of HTTP endpoints. This is more reliable and works for both HTTP and gRPC services.

## Setup Instructions

### 1. Install Prometheus Stack (if not already installed)

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install tutorial prometheus-community/kube-prometheus-stack \
  --wait --timeout 10m
```

### 2. Install Blackbox Exporter

```bash
helm install tutorial-blackbox prometheus-community/prometheus-blackbox-exporter \
  --set fullnameOverride=tutorial-kube-prometheus-s-blackbox-exporter \
  --set service.port=19115
```

### 3. Apply Monitoring Configurations (Pod-Based - Recommended)

```bash
# Apply pod-based monitoring rules (works for both HTTP and gRPC services)
kubectl apply -f extras/prometheus/pod-rules.yaml
```

**Alternative (HTTP-only services):**
If you want to use blackbox probes (only works for HTTP services like frontend):

```bash
kubectl apply -f extras/prometheus/probes.yaml
kubectl apply -f extras/prometheus/rules.yaml
```

### 4. Configure Slack Notifications (Optional)

Create a Slack webhook secret:

```bash
kubectl create secret generic alertmanager-slack-webhook \
  --from-literal=webhookURL='https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
```

Apply the Alertmanager configuration:

```bash
kubectl apply -f extras/prometheus/alertmanagerconfig.yaml
```

## Monitoring Coverage

The following microservices are monitored:

| Service | Port | Alert Severity |
|---------|------|----------------|
| frontend | 80 | Critical |
| cartservice | 7070 | Critical |
| checkoutservice | 5050 | Critical |
| paymentservice | 50051 | Critical |
| productcatalogservice | 3550 | Warning |
| currencyservice | 7000 | Warning |
| shippingservice | 50051 | Warning |
| emailservice | 5000 | Warning |
| recommendationservice | 8080 | Warning |
| adservice | 9555 | Warning |

## Access URLs

**Prometheus:**
```bash
kubectl port-forward svc/tutorial-kube-prometheus-s-prometheus 9090:9090
```
Then visit: http://localhost:9090

**Grafana:**
```bash
kubectl port-forward svc/tutorial-grafana 3000:80
```
Then visit: http://localhost:3000 (default login: admin/prom-operator)

**Alertmanager:**
```bash
kubectl port-forward svc/tutorial-kube-prometheus-s-alertmanager 9093:9093
```
Then visit: http://localhost:9093

## Verification Commands

Check if all components are running:
```bash
# Check probes
kubectl get probes

# Check rules
kubectl get prometheusrules

# Check blackbox exporter
kubectl get pods -l app.kubernetes.io/name=prometheus-blackbox-exporter

# View Prometheus targets
curl http://<prometheus-url>:9090/api/v1/targets | jq '.data.activeTargets[] | select(.scrapePool | startswith("probe/"))'

# View active alerts
curl http://<prometheus-url>:9090/api/v1/alerts | jq '.data.alerts[] | {name: .labels.alertname, state: .state}'
```

## Alert Rules

All services have uptime monitoring with the following alert configuration:

- **Check interval**: 60 seconds
- **Alert threshold**: Service unavailable for 1 minute
- **Severities**: 
  - Critical: frontend, cart, checkout, payment
  - Warning: other services

## Troubleshooting

### Alerts not showing up

1. Check if resources have the correct label:
```bash
kubectl get prometheusrule uptime-rule -o jsonpath='{.metadata.labels}'
kubectl get probes -o jsonpath='{.items[*].metadata.labels}'
```

They should have `release: tutorial` label.

2. Check Prometheus selector configuration:
```bash
kubectl get prometheus tutorial-kube-prometheus-s-prometheus -o yaml | grep -A 5 "probeSelector\|ruleSelector"
```

3. Reload Prometheus configuration:
```bash
kubectl delete pod -l app.kubernetes.io/name=prometheus
```

### Probes failing

1. Check blackbox exporter is running:
```bash
kubectl get svc tutorial-kube-prometheus-s-blackbox-exporter
```

2. Check probe status:
```bash
kubectl describe probe <probe-name>
```

3. Test blackbox exporter manually:
```bash
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl "http://tutorial-kube-prometheus-s-blackbox-exporter:19115/probe?module=http_2xx&target=frontend:80"
```

## Created By

This monitoring setup was created to provide comprehensive observability for the Online Boutique microservices demo application running on AWS EKS.

