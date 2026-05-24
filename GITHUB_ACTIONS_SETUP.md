# GitHub Actions Setup Guide

This guide walks you through setting up GitHub Actions for automated deployment of your Lambda function to AWS.

## Prerequisites

1. **GitHub Repository** - Your code must be in a GitHub repository
2. **AWS Account** - with appropriate permissions
3. **GitHub Secrets** - for storing AWS credentials securely

## Step 1: Create AWS IAM Role for GitHub Actions (RECOMMENDED)

This uses OIDC (OpenID Connect) for secure, keyless authentication - no long-lived credentials needed.

### Option A: Using AWS Console

1. Go to **IAM Console** → **Identity providers**
2. Click **Add provider** and select **OpenID Connect**
3. Provider URL: `https://token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`
5. Create an IAM role with CloudFormation, Lambda, S3, Secrets Manager, and IAM permissions
6. Add trust relationship for your GitHub repo:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
           },
           "StringLike": {
             "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO:*"
           }
         }
       }
     ]
   }
   ```

### Option B: Using AWS CLI

```bash
# Create OIDC provider
aws iam create-open-id-connect-provider \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Create trust policy
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF

# Create role
aws iam create-role \
    --role-name github-actions-lambda-deploy \
    --assume-role-policy-document file://trust-policy.json
```

## Step 2: Configure GitHub Secrets

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions**

Add these secrets:

### Required Secrets:

| Secret Name | Value | Description |
|------------|-------|-------------|
| `AWS_ACCOUNT_ID` | Your AWS Account ID | Used for S3 bucket naming |
| `AWS_ROLE_TO_ASSUME` | `arn:aws:iam::ACCOUNT_ID:role/github-actions-lambda-deploy` | OIDC role for authentication |

### Optional (if not using OIDC):

| Secret Name | Value |
|------------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS Access Key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS Secret Key |

## Step 3: Create Environments (Optional but Recommended)

For multi-environment deployments, create GitHub Environments:

1. **Settings** → **Environments** → **New environment**
2. Create: `dev`, `staging`, `prod`
3. For each environment, add deployment rules (optional):
   - Required reviewers for production
   - Deployment branches

## Step 4: Branch Configuration

The workflow uses branch-based deployment:

| Branch | Environment | Stack Name |
|--------|------------|-----------|
| `develop` | `dev` | `certificate-renewal-stack-dev` |
| `staging` | `staging` | `certificate-renewal-stack-staging` |
| `main` | `prod` | `certificate-renewal-stack-prod` |

Create these branches in your repository:
```bash
git checkout -b develop
git checkout -b staging
git checkout -b main
```

## Step 5: Initial Deployment

### First-time Setup:

1. **Push code to repository**
   ```bash
   git add .
   git commit -m "Add Lambda deployment automation"
   git push origin main
   ```

2. **GitHub Actions will automatically trigger** the deploy workflow

3. **Monitor the workflow** in **Actions** tab

4. **After successful deployment**, add Azure Entra secrets:
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

## Workflow Files Explained

### `deploy.yml` - Main Deployment Workflow
- **Trigger:** Push to main/develop/staging or manual trigger
- **Steps:**
  1. Checkout code
  2. Setup Python environment
  3. Create deployment package
  4. Upload to S3
  5. Validate CloudFormation template
  6. Deploy stack
  7. Run Lambda test
  8. Generate deployment summary

### `validate.yml` - Code Validation
- **Trigger:** Pull requests and pushes
- **Checks:**
  - Python syntax
  - Code formatting (Black)
  - Import sorting (isort)
  - Linting (Pylint)
  - CloudFormation template syntax
  - Security vulnerabilities (Safety)

### `destroy.yml` - Resource Destruction
- **Trigger:** Manual workflow dispatch
- **Safety:** Requires explicit confirmation
- **Deletes:**
  - CloudFormation stack
  - S3 buckets
  - Secrets Manager entries
  - IAM roles

## Usage Examples

### Deploy Development Version
```bash
git push origin develop
# Automatically deploys to dev environment
```

### Deploy Production Version
```bash
git push origin main
# Automatically deploys to prod environment with approval (if configured)
```

### Manual Deployment (for any environment)
1. Go to **Actions** → **Deploy Lambda to AWS**
2. Click **Run workflow**
3. Select branch and environment
4. Click **Run workflow**

### Destroy Environment (manual)
1. Go to **Actions** → **Destroy AWS Resources**
2. Select environment
3. Type "DELETE" for confirmation
4. Run workflow

## Monitoring Deployments

### View Workflow Status
- **Actions tab** - Real-time workflow progress
- **Commits** - Green checkmark = deployment successful

### View Lambda Logs
```bash
aws logs tail /aws/lambda/certificate-renewal-lambda-dev --follow --region ap-south-1
```

### Check Stack Status
```bash
aws cloudformation describe-stacks \
    --stack-name certificate-renewal-stack-dev \
    --region ap-south-1
```

## Troubleshooting

### Workflow Fails with "Access Denied"

**Solution:** Verify IAM role permissions include:
- `cloudformation:*`
- `lambda:*`
- `iam:*`
- `s3:*`
- `secretsmanager:GetSecretValue`
- `logs:*`
- `events:*`

### OIDC Token Validation Failed

**Solution:** Check:
1. GitHub repository URL matches trust policy
2. OIDC provider thumbprint is correct
3. Organization and repo name match exactly

### S3 Bucket Already Exists

**Solution:** Use unique bucket names in the template or add random suffix:
```bash
BUCKET_NAME="certificate-renewal-lambda-deployment-$RANDOM-$(date +%s)"
```

### Lambda Function Not Found After Deployment

**Solution:** Check CloudFormation stack creation:
```bash
aws cloudformation describe-stacks \
    --stack-name certificate-renewal-stack-dev \
    --region ap-south-1 \
    --query 'Stacks[0].StackStatus'
```

## Security Best Practices

✅ **Use OIDC authentication** (keyless) instead of long-lived credentials  
✅ **Store secrets** in GitHub Secrets, not in code  
✅ **Use separate environments** for dev/staging/prod  
✅ **Require approvals** for production deployments  
✅ **Enable branch protection** on main branch  
✅ **Audit workflow runs** in Actions history  
✅ **Rotate credentials** regularly  
✅ **Keep dependencies updated** in requirements.txt  

## GitHub Actions Pricing

- **Public repositories:** FREE (unlimited minutes)
- **Private repositories:** 2,000 minutes/month free, then $0.008/minute
- **Estimate for this workflow:** ~2-3 minutes per deployment

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS OIDC Provider Setup](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
