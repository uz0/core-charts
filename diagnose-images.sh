#!/bin/bash
# Diagnose what images are being pulled and why

echo "=========================================="
echo "Redis Images Being Pulled"
echo "=========================================="
kubectl describe pod -n redis 2>/dev/null | grep -E "Image:|Image ID:|Pulling|Failed|Back-off" || echo "No Redis pods"

echo ""
echo "=========================================="
echo "PostgreSQL Images Being Pulled"
echo "=========================================="
kubectl describe pod -n database 2>/dev/null | grep -E "Image:|Image ID:|Pulling|Failed|Back-off" || echo "No PostgreSQL pods"

echo ""
echo "=========================================="
echo "Redis StatefulSet Images"
echo "=========================================="
kubectl get statefulset -n redis -o yaml 2>/dev/null | grep -A2 "image:" || echo "No Redis StatefulSet"

echo ""
echo "=========================================="
echo "PostgreSQL StatefulSet Images"
echo "=========================================="
kubectl get statefulset -n database -o yaml 2>/dev/null | grep -A2 "image:" || echo "No PostgreSQL StatefulSet"

echo ""
echo "=========================================="
echo "Full Pod Descriptions"
echo "=========================================="
echo "Redis pods:"
kubectl describe pods -n redis 2>/dev/null | head -100

echo ""
echo "PostgreSQL pods:"
kubectl describe pods -n database 2>/dev/null | head -100

echo ""
echo "=========================================="
echo "Pod Events (Last 20)"
echo "=========================================="
echo "Redis events:"
kubectl get events -n redis --sort-by='.lastTimestamp' 2>/dev/null | tail -20

echo ""
echo "PostgreSQL events:"
kubectl get events -n database --sort-by='.lastTimestamp' 2>/dev/null | tail -20
