import boto3
import json

from config import (
    AWS_SECRET_NAME,
    AWS_REGION
)

client = boto3.client(
    "secretsmanager",
    region_name=AWS_REGION
)

def store_token_secret(secret_data):

    secret_string = json.dumps(secret_data)

    try:

        client.create_secret(
            Name=AWS_SECRET_NAME,
            SecretString=secret_string
        )

    except client.exceptions.ResourceExistsException:

        client.put_secret_value(
            SecretId=AWS_SECRET_NAME,
            SecretString=secret_string
        )