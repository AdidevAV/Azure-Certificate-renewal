# PowerShell deployment script for Lambda function

param(
    [Parameter(Mandatory=$true)]
    [string]$AWSAccessKeyId,
    
    [Parameter(Mandatory=$true)]
    [string]$AWSSecretAccessKey,
    
    [Parameter(Mandatory=$true)]
    [string]$AWSRegion = "ap-south-1",
    
    [Parameter(Mandatory=$false)]
    [string]$FunctionName = "certificate-renewal-lambda",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$StackName = "certificate-renewal-stack"
)

# Set AWS credentials
$env:AWS_ACCESS_KEY_ID = $AWSAccessKeyId
$env:AWS_SECRET_ACCESS_KEY = $AWSSecretAccessKey
$env:AWS_DEFAULT_REGION = $AWSRegion

Write-Host "==========================================="
Write-Host "Certificate Renewal Lambda - Deployment"
Write-Host "==========================================="
Write-Host "Function Name: $FunctionName"
Write-Host "Environment: $Environment"
Write-Host "Region: $AWSRegion"
Write-Host "Stack Name: $StackName"
Write-Host ""

# Step 1: Create deployment package
Write-Host "Step 1: Creating deployment package..."
$zipFile = "lambda-code.zip"

if (Test-Path $zipFile) {
    Remove-Item $zipFile -Force
}

# Add all Python files to zip
Add-Type -AssemblyName System.IO.Compression.FileSystem

$sourceFiles = @(
    "lambda_function.py",
    "config.py",
    "certificate_manager.py",
    "graph_api.py",
    "graph_auth.py",
    "secrets_manager.py",
    "token_generator.py"
)

# Create temporary directory for package
$tempDir = "lambda-package"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Copy source files
foreach ($file in $sourceFiles) {
    if (Test-Path $file) {
        Copy-Item $file -Destination $tempDir
        Write-Host "  Added: $file"
    } else {
        Write-Host "  WARNING: $file not found"
    }
}

# Install dependencies in package directory
Write-Host "Installing dependencies..."
pip install -r requirement.txt -t $tempDir --quiet

# Create zip file
[System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipFile)
Write-Host "Deployment package created: $zipFile"
Write-Host ""

# Step 2: Upload to S3 (will be created by CloudFormation)
Write-Host "Step 2: Validating CloudFormation template..."
aws cloudformation validate-template `
    --template-body file://template.yaml `
    --region $AWSRegion `
    --profile default 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: CloudFormation template validation failed"
    exit 1
}
Write-Host "Template validation successful"
Write-Host ""

# Step 3: Deploy CloudFormation stack
Write-Host "Step 3: Deploying CloudFormation stack..."
aws cloudformation deploy `
    --template-file template.yaml `
    --stack-name $StackName `
    --parameter-overrides `
        FunctionName=$FunctionName `
        Environment=$Environment `
    --capabilities CAPABILITY_NAMED_IAM `
    --region $AWSRegion

if ($LASTEXITCODE -eq 0) {
    Write-Host "Stack deployment successful!"
    Write-Host ""
    
    # Get stack outputs
    Write-Host "Stack Outputs:"
    aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $AWSRegion `
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' `
        --output table
} else {
    Write-Host "ERROR: Stack deployment failed"
    exit 1
}

Write-Host ""
Write-Host "==========================================="
Write-Host "Deployment Complete!"
Write-Host "==========================================="
Write-Host ""
Write-Host "Next Steps:"
Write-Host "1. Store Azure Entra secrets in AWS Secrets Manager:"
Write-Host "   aws secretsmanager create-secret --name $FunctionName/azure --secret-string '{\"TENANT_ID\":\"...\",\"ADMIN_CLIENT_ID\":\"...\",\"ADMIN_CLIENT_SECRET\":\"...\",\"TARGET_CLIENT_ID\":\"...\"}' --region $AWSRegion"
Write-Host ""
Write-Host "2. Test the Lambda function:"
Write-Host "   aws lambda invoke --function-name $FunctionName-$Environment --region $AWSRegion response.json"
Write-Host ""
Write-Host "3. View logs:"
Write-Host "   aws logs tail /aws/lambda/$FunctionName-$Environment --follow --region $AWSRegion"
