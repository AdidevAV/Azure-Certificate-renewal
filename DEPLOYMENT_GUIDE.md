# AWS Lambda Deployment Guide

This guide walks you through deploying the Certificate Renewal Lambda function to AWS using CloudFormation.

## Prerequisites

1. **AWS Account** - with appropriate permissions
2. **AWS CLI** - installed and configured
3. **PowerShell** - for running deployment script (or use bash alternative)
4. **Python 3.11** - for local testing
5. **Azure Entra ID Configuration** - TENANT_ID, ADMIN_CLIENT_ID, ADMIN_CLIENT_SECRET, TARGET_CLIENT_ID

## Step 1: Prepare Your AWS Credentials

You'll need:
- **AWS Access Key ID**
- **AWS Secret Access Key**
- **AWS Region** (default: ap-south-1)

If you don't have these:
1. Go to AWS IAM Console
2. Create a new IAM user with programmatic access
3. Attach policy: `AdministratorAccess` or custom policy with Lambda, CloudFormation, IAM, S3, and Secrets Manager permissions
4. Generate access keys

## Step 2: Prepare Azure Entra Configuration

Have these values ready:
- `TENANT_ID` - Your Azure AD tenant ID
- `ADMIN_CLIENT_ID` - The client ID of the admin application registration
- `ADMIN_CLIENT_SECRET` - The client secret
- `TARGET_CLIENT_ID` - The client ID of the target application

## Step 3: Run the Deployment Script

### Option A: Using PowerShell (Windows)

```powershell
.\deploy.ps1 `
    -AWSAccessKeyId "YOUR_ACCESS_KEY" `
    -AWSSecretAccessKey "YOUR_SECRET_KEY" `
    -AWSRegion "ap-south-1" `
    -FunctionName "certificate-renewal-lambda" `
    -Environment "dev"
```

### Option B: Using AWS CLI Directly

```bash
# Set credentials
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
export AWS_DEFAULT_REGION=ap-south-1

# Create deployment package
pip install -r requirement.txt -t lambda-package
cd lambda-package
zip -r ../lambda-code.zip .
cd ..
zip lambda-code.zip *.py

# Create S3 bucket for deployment
aws s3 mb s3://certificate-renewal-lambda-deployment-$(aws sts get-caller-identity --query Account --output text)

# Upload code
aws s3 cp lambda-code.zip s3://certificate-renewal-lambda-deployment-$(aws sts get-caller-identity --query Account --output text)/

# Deploy stack
aws cloudformation deploy \
    --template-file template.yaml \
    --stack-name certificate-renewal-stack \
    --parameter-overrides FunctionName=certificate-renewal-lambda Environment=dev \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ap-south-1
```

## Step 4: Configure Azure Secrets in AWS Secrets Manager

After the stack is deployed, store your Azure Entra configuration:

```bash
aws secretsmanager create-secret \
    --name certificate-renewal-lambda/azure \
    --secret-string '{
        "TENANT_ID": "your-tenant-id",
        "ADMIN_CLIENT_ID": "your-admin-client-id",
        "ADMIN_CLIENT_SECRET": "your-admin-client-secret",
        "TARGET_CLIENT_ID": "your-target-client-id"
    }' \
    --region ap-south-1
```

## Step 5: Test the Lambda Function

### Test via AWS Console
1. Go to AWS Lambda Console
2. Select your function: `certificate-renewal-lambda-dev`
3. Click "Test" → Create a test event (default JSON)
4. Execute and check the response

### Test via AWS CLI

```bash
aws lambda invoke \
    --function-name certificate-renewal-lambda-dev \
    --region ap-south-1 \
    response.json

cat response.json
```

### View Logs

```bash
aws logs tail /aws/lambda/certificate-renewal-lambda-dev --follow --region ap-south-1
```

## Scheduled Execution

The CloudFormation template includes an EventBridge rule that runs the function daily at **2:00 AM UTC**. 

To modify the schedule, edit `template.yaml`:
```yaml
ScheduleExpression: 'cron(0 2 * * ? *)'  # Modify this
```

CloudWatch Events cron format:
- `cron(0 0 * * ? *)` - Daily at midnight UTC
- `cron(0 */6 * * ? *)` - Every 6 hours
- `cron(0 0 ? * MON *)` - Weekly on Monday

## Update Deployment

To update the Lambda function code:

1. Modify your Python files
2. Create new deployment package:
   ```bash
   # Clean and recreate
   rm -rf lambda-package lambda-code.zip
   mkdir lambda-package
   cp *.py lambda-package/
   pip install -r requirement.txt -t lambda-package
   cd lambda-package && zip -r ../lambda-code.zip . && cd ..
   ```

3. Update the CloudFormation stack:
   ```bash
   aws cloudformation update-stack \
       --stack-name certificate-renewal-stack \
       --template-body file://template.yaml \
       --parameter-overrides FunctionName=certificate-renewal-lambda Environment=dev \
       --capabilities CAPABILITY_NAMED_IAM \
       --region ap-south-1
   ```

## Troubleshooting

### Function Execution Fails
Check CloudWatch logs:
```bash
aws logs tail /aws/lambda/certificate-renewal-lambda-dev --follow --region ap-south-1
```

### Secrets Not Found
Verify secrets exist:
```bash
aws secretsmanager get-secret-value \
    --secret-id certificate-renewal-lambda/azure \
    --region ap-south-1
```

### Permission Denied
Check IAM role has permissions for:
- `secretsmanager:GetSecretValue`
- `secretsmanager:PutSecretValue`
- CloudWatch Logs (`logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`)

### Stack Creation Failed
Validate template:
```bash
aws cloudformation validate-template --template-body file://template.yaml
```

## Environment Variables

The Lambda function uses the following environment variables:

| Variable | Source | Description |
|----------|--------|-------------|
| TENANT_ID | Secrets Manager | Azure Entra tenant ID |
| ADMIN_CLIENT_ID | Secrets Manager | Admin app client ID |
| ADMIN_CLIENT_SECRET | Secrets Manager | Admin app secret |
| TARGET_CLIENT_ID | Secrets Manager | Target app client ID |
| AWS_SECRET_NAME | Template | S3 location for token storage |
| AWS_REGION | Template | AWS region |

## Cost Estimation

- **Lambda Invocations**: $0.20 per 1M requests (~$1/month if run daily)
- **CloudWatch Logs**: ~$0.50-2/month depending on output
- **Secrets Manager**: $0.40/secret/month
- **S3 Storage**: Minimal (< $1/month)

**Monthly estimate**: ~$2-4

## Security Best Practices

1. ✅ Store secrets in AWS Secrets Manager (not environment variables)
2. ✅ Use IAM roles with minimal permissions
3. ✅ Enable CloudFormation stack policy
4. ✅ Use different stacks for dev/staging/prod
5. ✅ Enable CloudTrail for audit logging
6. ✅ Rotate Azure Entra client secrets regularly

## Clean Up

To delete all resources:

```bash
# Delete secrets
aws secretsmanager delete-secret \
    --secret-id certificate-renewal-lambda/azure \
    --force-delete-without-recovery \
    --region ap-south-1

# Delete CloudFormation stack
aws cloudformation delete-stack \
    --stack-name certificate-renewal-stack \
    --region ap-south-1
```

## Additional Resources

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [CloudFormation User Guide](https://docs.aws.amazon.com/cloudformation/)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [EventBridge Rules](https://docs.aws.amazon.com/eventbridge/)
