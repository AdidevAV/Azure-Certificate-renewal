#!/bin/bash

# Bash deployment script for Lambda function
# Usage: ./deploy.sh --access-key KEY --secret-key SECRET [--region REGION] [--function-name NAME] [--environment ENV]

set -e

# Parse arguments
ACCESS_KEY=""
SECRET_KEY=""
REGION="ap-south-1"
FUNCTION_NAME="certificate-renewal-lambda"
ENVIRONMENT="dev"
STACK_NAME="certificate-renewal-stack"

while [[ $# -gt 0 ]]; do
    case $1 in
        --access-key)
            ACCESS_KEY="$2"
            shift 2
            ;;
        --secret-key)
            SECRET_KEY="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --function-name)
            FUNCTION_NAME="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
    echo "Error: --access-key and --secret-key are required"
    exit 1
fi

# Set AWS credentials
export AWS_ACCESS_KEY_ID=$ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$SECRET_KEY
export AWS_DEFAULT_REGION=$REGION

echo "==========================================="
echo "Certificate Renewal Lambda - Deployment"
echo "==========================================="
echo "Function Name: $FUNCTION_NAME"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "Stack Name: $STACK_NAME"
echo ""

# Step 1: Create deployment package
echo "Step 1: Creating deployment package..."
ZIP_FILE="lambda-code.zip"

rm -f "$ZIP_FILE"
rm -rf lambda-package

mkdir -p lambda-package

# Copy source files
for file in lambda_function.py config.py certificate_manager.py graph_api.py graph_auth.py secrets_manager.py token_generator.py; do
    if [ -f "$file" ]; then
        cp "$file" lambda-package/
        echo "  Added: $file"
    else
        echo "  WARNING: $file not found"
    fi
done

# Install dependencies
echo "Installing dependencies..."
pip install -r requirement.txt -t lambda-package --quiet

# Create zip file
cd lambda-package
zip -r ../"$ZIP_FILE" . > /dev/null
cd ..

echo "Deployment package created: $ZIP_FILE"
echo ""

# Step 2: Validate CloudFormation template
echo "Step 2: Validating CloudFormation template..."
aws cloudformation validate-template \
    --template-body file://template.yaml \
    --region "$REGION" > /dev/null

if [ $? -eq 0 ]; then
    echo "Template validation successful"
else
    echo "ERROR: CloudFormation template validation failed"
    exit 1
fi
echo ""

# Step 3: Deploy CloudFormation stack
echo "Step 3: Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file template.yaml \
    --stack-name "$STACK_NAME" \
    --parameter-overrides \
        FunctionName="$FUNCTION_NAME" \
        Environment="$ENVIRONMENT" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION"

if [ $? -eq 0 ]; then
    echo "Stack deployment successful!"
    echo ""
    
    # Get stack outputs
    echo "Stack Outputs:"
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
else
    echo "ERROR: Stack deployment failed"
    exit 1
fi

echo ""
echo "==========================================="
echo "Deployment Complete!"
echo "==========================================="
echo ""
echo "Next Steps:"
echo "1. Store Azure Entra secrets in AWS Secrets Manager:"
echo "   aws secretsmanager create-secret --name $FUNCTION_NAME/azure --secret-string '{\"TENANT_ID\":\"...\",\"ADMIN_CLIENT_ID\":\"...\",\"ADMIN_CLIENT_SECRET\":\"...\",\"TARGET_CLIENT_ID\":\"...\"}' --region $REGION"
echo ""
echo "2. Test the Lambda function:"
echo "   aws lambda invoke --function-name $FUNCTION_NAME-$ENVIRONMENT --region $REGION response.json"
echo ""
echo "3. View logs:"
echo "   aws logs tail /aws/lambda/$FUNCTION_NAME-$ENVIRONMENT --follow --region $REGION"
