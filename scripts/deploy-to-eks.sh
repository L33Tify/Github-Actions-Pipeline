#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="user-management-eks-cluster"
REGION="us-east-2"
AWS_ACCOUNT_ID="737210140690"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
ALB_CONTROLLER_VERSION="2.14.1"
IAM_ROLE_NAME="user-management-dev-aws-load-balancer-controller"

echo -e "${GREEN}=== EKS Deployment Script ===${NC}\n"

# Function to print status
print_status() {
    echo -e "${YELLOW}>>> $1${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Step 1: Verify kubectl context
print_status "Verifying kubectl context..."
CURRENT_CONTEXT=$(kubectl config current-context)
if [[ "$CURRENT_CONTEXT" != *"$CLUSTER_NAME"* ]]; then
    print_error "Not connected to $CLUSTER_NAME"
    echo "Current context: $CURRENT_CONTEXT"
    echo "Run: aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME"
    exit 1
fi
print_success "Connected to $CLUSTER_NAME"

# Step 2: Get VPC ID from cluster
print_status "Getting VPC ID from EKS cluster..."
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)
print_success "VPC ID: $VPC_ID"

# Step 3: Get IAM Role ARN
print_status "Getting IAM Role ARN for AWS Load Balancer Controller..."
IAM_ROLE_ARN=$(aws iam get-role --role-name $IAM_ROLE_NAME --query 'Role.Arn' --output text 2>/dev/null || echo "")
if [ -z "$IAM_ROLE_ARN" ]; then
    print_error "IAM role $IAM_ROLE_NAME not found. Please run terraform apply first."
    exit 1
fi
print_success "IAM Role ARN: $IAM_ROLE_ARN"

# Step 4: Check if AWS Load Balancer Controller is installed
print_status "Checking AWS Load Balancer Controller..."
if helm list -n kube-system | grep -q "aws-load-balancer-controller"; then
    print_status "AWS Load Balancer Controller already installed, upgrading..."
    helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$IAM_ROLE_ARN \
        --set vpcId=$VPC_ID \
        --set region=$REGION
else
    print_status "Installing AWS Load Balancer Controller..."
    
    # Add EKS Helm repo if not already added
    if ! helm repo list | grep -q "eks"; then
        helm repo add eks https://aws.github.io/eks-charts
    fi
    helm repo update
    
    # Install AWS Load Balancer Controller
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$IAM_ROLE_ARN \
        --set vpcId=$VPC_ID \
        --set region=$REGION
fi

# Step 5: Wait for AWS Load Balancer Controller to be ready
print_status "Waiting for AWS Load Balancer Controller pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=aws-load-balancer-controller \
    -n kube-system \
    --timeout=300s

print_success "AWS Load Balancer Controller is ready"

# Step 6: Verify webhook is ready
print_status "Verifying webhook endpoints..."
WEBHOOK_ENDPOINTS=$(kubectl get endpoints -n kube-system aws-load-balancer-webhook-service -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
if [ -z "$WEBHOOK_ENDPOINTS" ]; then
    print_error "Webhook endpoints not ready yet, waiting 30 seconds..."
    sleep 30
    WEBHOOK_ENDPOINTS=$(kubectl get endpoints -n kube-system aws-load-balancer-webhook-service -o jsonpath='{.subsets[*].addresses[*].ip}')
fi
print_success "Webhook endpoints: $WEBHOOK_ENDPOINTS"

# Step 7: Check if namespaces exist (Helm will create them)
print_status "Checking namespaces..."
# We don't create them here - let Helm manage them from the chart
# Just verify kubectl can access the cluster
kubectl get namespaces > /dev/null 2>&1
print_success "Cluster access verified"

# Step 8: Deploy user-management-app
print_status "Deploying user-management-app..."
cd /home/l33t/iai/deplyment_project

# Get the latest commit SHA if deploying manually
if [ -z "$IMAGE_TAG" ]; then
    IMAGE_TAG=$(git rev-parse HEAD)
    print_status "Using git commit SHA: $IMAGE_TAG"
fi

if helm list | grep -q "user-management-app"; then
    print_status "Upgrading user-management-app..."
    helm upgrade user-management-app ./user-management-app \
        --set global.imageRegistry=$ECR_REGISTRY \
        --set backend.image.tag=$IMAGE_TAG \
        --set frontend.image.tag=$IMAGE_TAG \
        --wait \
        --timeout=5m
else
    print_status "Installing user-management-app..."
    helm install user-management-app ./user-management-app \
        --set global.imageRegistry=$ECR_REGISTRY \
        --set backend.image.tag=$IMAGE_TAG \
        --set frontend.image.tag=$IMAGE_TAG \
        --wait \
        --timeout=5m
fi

print_success "Application deployed"

# Step 9: Wait for deployments to be ready
print_status "Waiting for backend deployment..."
kubectl wait --for=condition=available deployment/user-management-app-backend \
    -n user-management-backend \
    --timeout=300s

print_status "Waiting for frontend deployment..."
kubectl wait --for=condition=available deployment/user-management-app-frontend \
    -n user-management-frontend \
    --timeout=300s

print_success "All deployments are ready"

# Step 10: Check pods
print_status "Checking pod status..."
echo ""
echo "Backend pods:"
kubectl get pods -n user-management-backend -l app.kubernetes.io/name=user-management-app
echo ""
echo "Frontend pods:"
kubectl get pods -n user-management-frontend -l app.kubernetes.io/name=user-management-app
echo ""

# Step 11: Wait for ingress to get ALB address
print_status "Waiting for ALB to be provisioned (this may take 2-3 minutes)..."
INGRESS_ADDRESS=""
for i in {1..60}; do
    INGRESS_ADDRESS=$(kubectl get ingress user-management-app -n user-management-frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$INGRESS_ADDRESS" ]; then
        break
    fi
    echo -n "."
    sleep 5
done
echo ""

if [ -z "$INGRESS_ADDRESS" ]; then
    print_error "ALB address not populated in ingress yet"
    echo "Checking AWS directly..."
    ALB_DNS=$(aws elbv2 describe-load-balancers --region $REGION \
        --query "LoadBalancers[?VpcId=='$VPC_ID' && starts_with(LoadBalancerName, 'k8s-userman')].DNSName | [0]" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$ALB_DNS" ] && [ "$ALB_DNS" != "None" ]; then
        INGRESS_ADDRESS=$ALB_DNS
        print_success "Found ALB DNS: $INGRESS_ADDRESS"
    else
        print_error "Could not find ALB. Check ingress events:"
        kubectl describe ingress user-management-app -n user-management-frontend | tail -20
        exit 1
    fi
else
    print_success "ALB provisioned: $INGRESS_ADDRESS"
fi

# Step 12: Get target group and check health
print_status "Checking target group health..."
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups --region $REGION \
    --query "TargetGroups[?VpcId=='$VPC_ID' && contains(TargetGroupName, 'usermana')].TargetGroupArn | [0]" \
    --output text 2>/dev/null || echo "")

if [ -n "$TARGET_GROUP_ARN" ] && [ "$TARGET_GROUP_ARN" != "None" ]; then
    echo "Target Group ARN: $TARGET_GROUP_ARN"
    
    TARGET_HEALTH=$(aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --region $REGION 2>/dev/null || echo "")
    
    if [ -n "$TARGET_HEALTH" ]; then
        HEALTHY_COUNT=$(echo "$TARGET_HEALTH" | jq -r '.TargetHealthDescriptions | length')
        echo "Registered targets: $HEALTHY_COUNT"
        
        if [ "$HEALTHY_COUNT" -gt 0 ]; then
            echo "$TARGET_HEALTH" | jq -r '.TargetHealthDescriptions[] | "  - Target: \(.Target.Id):\(.Target.Port) - State: \(.TargetHealth.State)"'
        else
            print_error "No targets registered yet. Checking again in 30 seconds..."
            sleep 30
            TARGET_HEALTH=$(aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --region $REGION)
            echo "$TARGET_HEALTH" | jq -r '.TargetHealthDescriptions[] | "  - Target: \(.Target.Id):\(.Target.Port) - State: \(.TargetHealth.State)"'
        fi
    fi
else
    print_error "Could not find target group"
fi

# Step 13: Test ALB endpoint
print_status "Testing ALB endpoint..."
sleep 10  # Give a moment for DNS propagation

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$INGRESS_ADDRESS/ --max-time 10 || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
    print_success "ALB is responding with HTTP 200"
elif [ "$HTTP_STATUS" = "000" ]; then
    print_error "Could not connect to ALB (timeout or DNS not ready)"
    echo "You may need to wait a few more minutes for DNS propagation"
else
    print_error "ALB responded with HTTP $HTTP_STATUS"
fi

# Final summary
echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Application URL: http://$INGRESS_ADDRESS"
echo ""
echo "Quick commands:"
echo "  - View pods:           kubectl get pods -n user-management-frontend"
echo "  - View ingress:        kubectl get ingress -n user-management-frontend"
echo "  - View ALB logs:       kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller"
echo "  - Check target health: aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --region $REGION"
echo ""
