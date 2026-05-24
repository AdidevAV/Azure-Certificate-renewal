# GitHub Actions Deployment - Setup Guide (No AWS CLI Required)

This guide walks you through setting up automated deployment using GitHub Actions - everything happens in the cloud, no need for AWS CLI locally.

## Prerequisites

1. ✅ GitHub account and repository
2. ✅ AWS account
3. ✅ A web browser
4. That's it!

## Step 1: Create AWS IAM Role for GitHub (5 minutes)

### Via AWS Console:

1. **Sign in to AWS Console** → Go to **IAM Dashboard**

2. **Create OIDC Provider:**
   - Left sidebar → **Identity Providers** → **Add Provider**
   - **Provider Type:** OpenID Connect
   - **Provider URL:** `https://token.actions.githubusercontent.com`
   - **Audience:** `sts.amazonaws.com`
   - Click **Add provider**

3. **Create IAM Role:**
   - Left sidebar → **Roles** → **Create role**
   - **Trusted entity type:** Web identity
   - **Identity provider:** `token.actions.githubusercontent.com`
   - **Audience:** `sts.amazonaws.com`
   - Click **Next**

4. **Add Permissions:**
   - Search and select these policies:
     - `AdministratorAccess` (for simplicity)
     - OR manually add: Lambda, CloudFormation, S3, IAM, Secrets Manager, CloudWatch, EventBridge
   - Click **Next**

5. **Name the Role:**
   - **Role name:** `github-actions-lambda-deploy`
   - Click **Create role**

6. **Edit Trust Relationship:**
   - Click the role you just created
   - **Trust relationships** tab → **Edit trust policy**
   - Replace with:
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
             "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/YOUR_REPO:*"
           }
         }
       }
     ]
   }
   ```
   - Replace `ACCOUNT_ID` with your AWS account number (find in top-right corner)
   - Replace `YOUR_GITHUB_USERNAME/YOUR_REPO` with your actual repo path
   - Click **Update policy**

## Step 2: Get Your AWS Account ID

1. Click your **Account ID** in the top-right corner of AWS Console
2. Copy it (12-digit number)
3. Save it for the next step

## Step 3: Get IAM Role ARN

1. Go to **IAM** → **Roles** → **github-actions-lambda-deploy**
2. Copy the **Role ARN** from the top (looks like `arn:aws:iam::123456789012:role/github-actions-lambda-deploy`)
3. Save it

## Step 4: Add GitHub Secrets

1. Go to your **GitHub repository**
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

Add these two secrets:

### Secret 1: AWS_ACCOUNT_ID
- **Name:** `AWS_ACCOUNT_ID`
- **Value:** Your 12-digit AWS account number (from Step 2)
- Click **Add secret**

### Secret 2: AWS_ROLE_TO_ASSUME
- **Name:** `AWS_ROLE_TO_ASSUME`
- **Value:** The role ARN (from Step 3)
- Click **Add secret**

## Step 5: Push Code to GitHub

1. Create a GitHub repository (if you don't have one)
2. Push your code:
   ```powershell
   # Initialize git repo
   git init
   git add .
   git commit -m "Initial commit with Lambda deployment setup"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
   git push -u origin main
   ```

3. **GitHub Actions will automatically start the deployment!**
   - Go to **Actions** tab in your repo
   - Watch the deployment progress
   - ✅ Deployment completes automatically

## Step 6: Add Azure Entra Secrets (via AWS Console)

After deployment completes, add your Azure configuration:

1. Go to **AWS Console** → **Secrets Manager**
2. Click **Store a new secret**
3. **Secret type:** Other type of secret
4. **Key/value pairs:**
   ```
   TENANT_ID = your-azure-tenant-id
   ADMIN_CLIENT_ID = your-admin-client-id
   ADMIN_CLIENT_SECRET = your-admin-secret
   TARGET_CLIENT_ID = your-target-client-id
   ```
5. Click **Next**
6. **Secret name:** `certificate-renewal-lambda/azure`
7. **Description:** Optional
8. Click **Store secret**

## Step 7: Test the Deployment

### Option A: Manual Test via AWS Console
1. Go to **AWS Lambda**
2. Find function: `certificate-renewal-lambda-dev`
3. Click **Test**
4. Create a test event (use default JSON)
5. Click **Test** → Check response

### Option B: Check CloudWatch Logs
1. Go to **CloudWatch** → **Log groups**
2. Select `/aws/lambda/certificate-renewal-lambda-dev`
3. View recent logs

## Deployment Workflow

### Automatic Deployments:

| Action | Result |
|--------|--------|
| Push to `main` branch | Deploys to Production |
| Push to `staging` branch | Deploys to Staging |
| Push to `develop` branch | Deploys to Development |

### Manual Deployment:
1. Go to GitHub repo **Actions** tab
2. Select **Deploy Lambda to AWS**
3. Click **Run workflow**
4. Select branch
5. Click **Run workflow**

## Monitoring Deployments

### View Workflow Status:
1. Go to **Actions** tab
2. Click the workflow run
3. View logs and progress in real-time

### View Function Logs:
1. **AWS Console** → **CloudWatch** → **Log groups**
2. `/aws/lambda/certificate-renewal-lambda-dev`
3. View recent logs

### Check Deployment Status:
1. **AWS Console** → **CloudFormation**
2. Find stack: `certificate-renewal-stack-dev`
3. Check **Status** column

## Troubleshooting

### Workflow Failed with "Access Denied"

**Check:**
1. GitHub Secrets are set correctly (AWS_ACCOUNT_ID and AWS_ROLE_TO_ASSUME)
2. IAM role trust policy has correct GitHub repo path
3. IAM role has required permissions (AdministratorAccess or specific policy)

**Fix:**
1. Go to **IAM** → **Roles** → **github-actions-lambda-deploy**
2. Check **Trust relationships** tab
3. Update the trust policy with correct repo path

### S3 Bucket Already Exists

**This is normal.** AWS creates an S3 bucket for Lambda code. If it already exists:
- The workflow will use the existing bucket
- No action needed

### Lambda Function Not Created

**Check CloudFormation:**
1. **AWS Console** → **CloudFormation**
2. Look for stack: `certificate-renewal-stack-dev`
3. Check **Events** tab for errors
4. Check **Resources** tab to see what was created

### Secrets Not Found by Lambda

**Verify secrets exist:**
1. **AWS Console** → **Secrets Manager**
2. Look for: `certificate-renewal-lambda/azure`
3. If missing, create it (see Step 6)

## What Happens Automatically

When you push code to GitHub:

1. ✅ Code validation runs (checks syntax, formatting, linting)
2. ✅ Code is packaged with all dependencies
3. ✅ Package is uploaded to S3
4. ✅ CloudFormation creates/updates infrastructure
5. ✅ Lambda function is deployed
6. ✅ EventBridge schedule is configured (daily at 2 AM UTC)
7. ✅ Lambda is tested automatically
8. ✅ Logs are generated
9. ✅ Deployment summary is created

Everything happens in AWS - no local tools needed!

## Scheduled Execution

The Lambda function runs automatically **every day at 2:00 AM UTC**.

To change the schedule:
1. Edit `.github/workflows/deploy.yml`
2. Find line: `ScheduleExpression: 'cron(0 2 * * ? *)'`
3. Change the cron time (find cron format online)
4. Push to GitHub - workflow updates automatically

## Cost

- **Lambda:** ~$1/month (for daily execution)
- **CloudWatch Logs:** ~$0.50-1/month
- **Secrets Manager:** $0.40/secret/month
- **Total:** ~$2-3/month

## Next Steps

1. ✅ Create AWS IAM role
2. ✅ Add GitHub secrets
3. ✅ Push code to GitHub
4. ✅ Watch deployment in Actions tab
5. ✅ Add Azure secrets in Secrets Manager
6. ✅ Monitor Lambda execution in CloudWatch

## Environment Variables

The Lambda function uses these environment variables (automatically set by CloudFormation):

| Variable | Source | Value |
|----------|--------|-------|
| TENANT_ID | Secrets Manager | `certificate-renewal-lambda/azure` |
| ADMIN_CLIENT_ID | Secrets Manager | `certificate-renewal-lambda/azure` |
| ADMIN_CLIENT_SECRET | Secrets Manager | `certificate-renewal-lambda/azure` |
| TARGET_CLIENT_ID | Secrets Manager | `certificate-renewal-lambda/azure` |
| AWS_SECRET_NAME | CloudFormation | `certificate-renewal-lambda/tokens` |
| AWS_REGION | CloudFormation | `ap-south-1` |

## Cleanup

To delete all AWS resources:

1. Go to **GitHub Actions** → **Destroy AWS Resources**
2. Click **Run workflow**
3. Select environment (dev/staging/prod)
4. Type `DELETE` in confirmation field
5. Click **Run workflow**
6. All resources are deleted automatically

## Security Notes

✅ No credentials stored in GitHub code  
✅ AWS OIDC provides secure, keyless authentication  
✅ Secrets stored securely in AWS Secrets Manager  
✅ IAM role has minimal required permissions  
✅ Audit trail in CloudFormation stack events  

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS OIDC Setup](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS CloudFormation](https://aws.amazon.com/cloudformation/)
- [AWS Lambda](https://aws.amazon.com/lambda/)
- [Cron Expression Format](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-cron-expressions.html)
