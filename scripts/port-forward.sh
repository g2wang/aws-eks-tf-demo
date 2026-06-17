#!/usr/bin/env bash
set -euo pipefail

echo "=== EKS Port Forward Helper ==="
echo "Select which service to port-forward:"
echo "1) Kibana Dashboard (exposes on http://localhost:5601)"
echo "2) Spring Boot Application (exposes on http://localhost:8080)"
read -r -p "Enter choice (1 or 2): " choice

if [ "$choice" = "1" ]; then
  echo "Finding Kibana service..."
  # Tries to find the kibana service dynamically, fallback to kibana-kibana
  KIBANA_SVC=$(kubectl get svc -n logging -o jsonpath='{.items[?(@.metadata.labels.app=="kibana")].metadata.name}' 2>/dev/null)
  if [ -z "$KIBANA_SVC" ]; then
    KIBANA_SVC="kibana-kibana"
  fi
  echo "Port forwarding service/$KIBANA_SVC to http://localhost:5601... Press Ctrl+C to exit."
  kubectl port-forward "svc/$KIBANA_SVC" 5601:5601 -n logging
elif [ "$choice" = "2" ]; then
  echo "Port forwarding service/time-service to http://localhost:8080... Press Ctrl+C to exit."
  kubectl port-forward svc/time-service 8080:80 -n default
else
  echo "Invalid option: $choice"
  exit 1
fi
