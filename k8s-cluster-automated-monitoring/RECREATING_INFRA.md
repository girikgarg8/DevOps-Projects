# 🔧 Recreating the Infrastructure

This guide provides minimal steps to recreate the complete monitoring infrastructure for demo recording.

---

## Prerequisites

```bash
# Ensure AWS CLI is configured
aws configure list

# Ensure kubectl is installed
kubectl version --client

# Ensure Helm is installed (or use the provided script)
helm version
# OR
chmod +x get_helm.sh && ./get_helm.sh
```

---

## Step 1: Create EKS Cluster

**Why:** Managed Kubernetes cluster on AWS to host application and monitoring stack.

```bash
# Using eksctl (adjust region, node count as needed)
eksctl create cluster \
  --name monitoring-demo-cluster \
  --region ap-south-1 \
  --nodegroup-name standard-workers \
  --node-type m7i-flex.large \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed

# Wait ~15-20 minutes for cluster creation
# Verify cluster access
kubectl get nodes
```

**Alternative using existing cluster:**
```bash
# Update kubeconfig
aws eks update-kubeconfig --region ap-south-1 --name <your-cluster-name>
```

---

## Step 2: Deploy Online Boutique Application

**Why:** 11-microservice demo application to monitor.

```bash
cd online-boutique

# Deploy all microservices
kubectl apply -f release/kubernetes-manifests.yaml

# Verify all services are running
kubectl get pods
kubectl get svc

# Get frontend LoadBalancer URL (may take 2-3 minutes to provision)
kubectl get svc frontend-external -w
```

---

## Step 3: Add Prometheus Helm Repository

**Why:** Access to kube-prometheus-stack chart for monitoring.

```bash
# Add Prometheus community repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update repo
helm repo update

# Verify repo is added
helm repo list
```

---

## Step 4: Install Prometheus Stack

**Why:** Deploy Prometheus, Grafana, Alertmanager, and exporters optimized for EKS.

**Note:** The `eks-values.yaml` already configures Prometheus and Grafana services as type `LoadBalancer`, so no manual patching needed.

```bash
cd online-boutique/extras/prometheus

# Install using EKS-optimized values
# This automatically exposes Prometheus and Grafana via LoadBalancer
helm install tutorial prometheus-community/kube-prometheus-stack \
  --namespace default \
  -f eks-values.yaml \
  --version 61.3.0

# Wait for all pods to be ready (~2-3 minutes)
kubectl get pods -l "release=tutorial" -w

# Verify services are exposed as LoadBalancer
kubectl get svc | grep -E "prometheus|grafana"
```

**Note the LoadBalancer URLs:**
```bash
# Prometheus
export PROMETHEUS_URL=$(kubectl get svc tutorial-kube-prometheus-s-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Prometheus: http://$PROMETHEUS_URL:9090"

# Grafana
export GRAFANA_URL=$(kubectl get svc tutorial-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Grafana: http://$GRAFANA_URL"

# Get Grafana admin password (stored as base64-encoded secret)
export GRAFANA_PASSWORD=$(kubectl get secret tutorial-grafana -o jsonpath="{.data.admin-password}" | base64 --decode)
echo "Grafana Username: admin"
echo "Grafana Password: $GRAFANA_PASSWORD"
```

---

## Step 5: Deploy Custom Alert Rules

**Why:** Monitor Online Boutique service availability with pod-based health checks.

```bash
cd online-boutique/extras/prometheus

# Apply custom PrometheusRule for all 11 microservices
kubectl apply -f pod-rules.yaml

# Verify rules are created
kubectl get prometheusrule online-boutique-pod-uptime

# Check Prometheus picked up the rules (wait 30 seconds)
# Navigate to Prometheus UI > Status > Rules
# Should see "Online Boutique Pod Health" rule group
```

---

## Step 6: Configure Alertmanager (Slack Integration)

**Why:** Route critical alerts to Slack for incident notification.

```bash
cd online-boutique/extras/prometheus

# Step 6.1: Create Kubernetes secret with Slack webhook URL
kubectl create secret generic alertmanager-slack-webhook \
  --from-literal=webhookURL='https://hooks.slack.com/services/YOUR/WEBHOOK/URL' \
  -n default

# Replace YOUR/WEBHOOK/URL with your actual Slack webhook path

# Verify secret is created
kubectl get secret alertmanager-slack-webhook -n default

# Step 6.2: Apply AlertManager configuration
# (This references the secret created above)
kubectl apply -f alertmanagerconfig.yaml

# Verify config is applied
kubectl get alertmanagerconfig slack-config

# Step 6.3: Restart Alertmanager to pick up config
kubectl delete pod -l app.kubernetes.io/name=alertmanager -n default

# Wait for new Alertmanager pod to be ready
kubectl get pods -l app.kubernetes.io/name=alertmanager -w
```

---

## Step 7: Verification Checklist

```bash
# 1. All Online Boutique pods running
kubectl get pods | grep -v Completed
# Should see: frontend, cartservice, productcatalog, currency, payment, shipping, email, checkout, recommendation, adservice, redis-cart, loadgenerator

# 2. All monitoring pods running
kubectl get pods -l "release=tutorial"
# Should see: prometheus, grafana, alertmanager, kube-state-metrics, prometheus-node-exporter, prometheus-operator

# 3. All services have LoadBalancers (External-IPs)
kubectl get svc

# 4. Access endpoints
echo "Application: http://$(kubectl get svc frontend-external -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Prometheus: http://$(kubectl get svc tutorial-kube-prometheus-s-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):9090"
echo "Grafana: http://$(kubectl get svc tutorial-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

# 5. Check Prometheus targets (all should be UP)
# Navigate to: Prometheus UI > Status > Targets

# 6. Check Prometheus alerts (should have Watchdog firing)
# Navigate to: Prometheus UI > Alerts

# 7. Login to Grafana
# Get the password first:
kubectl get secret tutorial-grafana -o jsonpath="{.data.admin-password}" | base64 --decode && echo
# Username: admin
# Password: (output from above command)
# Navigate to Dashboards > Browse
```

---

## Step 8: Test Alert Before Recording

**Why:** Verify end-to-end alerting works before demo recording.

```bash
# Scale down a service to trigger alert
kubectl scale deployment paymentservice --replicas=0

# Wait 1-2 minutes, then check Prometheus Alerts page
# Should see "PaymentserviceUnavailable" alert firing

# Check Slack channel for alert notification

# Scale back up to resolve
kubectl scale deployment paymentservice --replicas=1

# Verify alert resolves in Prometheus (may take 1-2 minutes)
# Verify resolved notification in Slack
```

---

## Cleanup (After Demo Recording)

```bash
# Delete Helm release
helm uninstall tutorial -n default

# Delete Online Boutique
kubectl delete -f online-boutique/release/kubernetes-manifests.yaml

# Delete custom resources
kubectl delete -f online-boutique/extras/prometheus/pod-rules.yaml
kubectl delete -f online-boutique/extras/prometheus/alertmanagerconfig.yaml

# Delete Slack webhook secret
kubectl delete secret alertmanager-slack-webhook -n default

# Delete EKS cluster (if created specifically for demo)
eksctl delete cluster --name monitoring-demo-cluster --region ap-south-1
```

---

## Troubleshooting

**Issue: LoadBalancer pending**
```bash
# Check AWS Load Balancer Controller is installed
kubectl get deployment -n kube-system aws-load-balancer-controller

# If not installed, EKS should create classic ELBs automatically
# Wait 3-5 minutes, check security groups allow traffic
```

**Issue: Services still showing ClusterIP instead of LoadBalancer**
```bash
# This shouldn't happen if eks-values.yaml was used, but if needed:

# Manually patch Prometheus service
kubectl patch svc tutorial-kube-prometheus-s-prometheus -n default -p '{"spec":{"type":"LoadBalancer"}}'

# Manually patch Grafana service
kubectl patch svc tutorial-grafana -n default -p '{"spec":{"type":"LoadBalancer"}}'

# Verify changes
kubectl get svc | grep -E "prometheus|grafana"

# Wait 2-3 minutes for LoadBalancer provisioning
```

**Issue: Can't login to Grafana**
```bash
# Get the admin password from secret
kubectl get secret tutorial-grafana -o jsonpath="{.data.admin-password}" | base64 --decode && echo

# Username is always: admin

# If secret doesn't exist, Grafana might not be ready yet
kubectl get pods -l app.kubernetes.io/name=grafana

# Check Grafana logs if login fails
kubectl logs -l app.kubernetes.io/name=grafana --tail=50
```

**Issue: Prometheus targets down**
```bash
# Check pod status
kubectl get pods -l "release=tutorial"

# Check ServiceMonitor labels
kubectl get servicemonitor -l "release=tutorial"
```

**Issue: Alerts not firing**
```bash
# Verify PrometheusRule has correct label
kubectl get prometheusrule online-boutique-pod-uptime -o yaml | grep "release: tutorial"

# Check Prometheus logs
kubectl logs -l app.kubernetes.io/name=prometheus --tail=100
```

**Issue: Slack alerts not received**
```bash
# 1. Verify the secret exists and has correct webhook URL
kubectl get secret alertmanager-slack-webhook -n default
kubectl get secret alertmanager-slack-webhook -n default -o jsonpath='{.data.webhookURL}' | base64 -d
# Should show: https://hooks.slack.com/services/...

# 2. Verify AlertManagerConfig is applied
kubectl get alertmanagerconfig slack-config -n default

# 3. Check Alertmanager logs for errors
kubectl logs -l app.kubernetes.io/name=alertmanager -n default --tail=100

# 4. Test webhook manually with curl
WEBHOOK_URL=$(kubectl get secret alertmanager-slack-webhook -n default -o jsonpath='{.data.webhookURL}' | base64 -d)
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test alert from kubectl"}' \
  "$WEBHOOK_URL"

# If curl succeeds but Alertmanager doesn't work, restart Alertmanager
kubectl delete pod -l app.kubernetes.io/name=alertmanager -n default
```

---

## Quick Reference - All Access URLs

```bash
# Run this script to get all URLs at once
cat << 'EOF' > get_urls.sh
#!/bin/bash
echo "=== Access URLs ==="
echo ""
echo "📱 Application:"
kubectl get svc frontend-external -o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}' && echo ""
echo ""
echo "📊 Prometheus:"
kubectl get svc tutorial-kube-prometheus-s-prometheus -o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}:9090' && echo ""
echo ""
echo "📈 Grafana:"
kubectl get svc tutorial-grafana -o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}' && echo ""
echo "   Username: admin"
echo -n "   Password: "
kubectl get secret tutorial-grafana -o jsonpath="{.data.admin-password}" | base64 --decode && echo ""
echo ""
echo "=== Cluster Info ==="
kubectl get nodes -o wide
EOF

chmod +x get_urls.sh
./get_urls.sh
```

---

## Estimated Timeline

- EKS Cluster Creation: ~15-20 minutes
- Online Boutique Deployment: ~2-3 minutes
- Prometheus Stack Installation: ~3-5 minutes
- LoadBalancer Provisioning: ~2-3 minutes per service
- Alert Rule Propagation: ~1 minute
- **Total: ~25-30 minutes**

---

**Ready for Recording!** 🎬

Once all steps are complete and verified, infrastructure is ready for demo video recording.

