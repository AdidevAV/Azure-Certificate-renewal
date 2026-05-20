from graph_auth import (
    get_graph_access_token
)

from graph_api import (
    get_application_by_client_id,
    upload_certificate_to_application
)

from certificate_manager import (
    generate_self_signed_certificate
)

from token_generator import (
    generate_token_using_certificate
)

from secrets_manager import (
    store_token_secret
)

from config import TARGET_CLIENT_ID

def lambda_handler(event, context):

    print("=" * 50)
    print("STEP 1 -> AUTHENTICATING TO GRAPH")
    print("=" * 50)

    graph_access_token = get_graph_access_token()

    print("Graph Authentication SUCCESS")

    print("=" * 50)
    print("STEP 2 -> SEARCHING TARGET APP")
    print("=" * 50)

    application = get_application_by_client_id(
        graph_access_token,
        TARGET_CLIENT_ID
    )

    application_object_id = application["id"]

    print(
        f"Target Application Found: "
        f"{application_object_id}"
    )

    print("=" * 50)
    print("STEP 3 -> GENERATING CERTIFICATE")
    print("=" * 50)

    cert_data = generate_self_signed_certificate()

    print(
        f"Thumbprint: "
        f"{cert_data['thumbprint']}"
    )

    print("=" * 50)
    print("STEP 4 -> UPLOADING CERTIFICATE")
    print("=" * 50)

    upload_certificate_to_application(
        graph_access_token,
        application_object_id,
        cert_data["cert_der"],
        "LambdaGeneratedCertificate"
    )

    import time

    print("Certificate Upload SUCCESS")
 
    print("Waiting 30 seconds for Azure propagation...")

    time.sleep(30)

    print("=" * 50)
    print("STEP 5 -> GENERATING OAUTH TOKEN")
    print("=" * 50)
   

    oauth_token = generate_token_using_certificate(
        cert_data["private_key_pem"],
        cert_data["thumbprint"],
        cert_data["cert_pem"]
    )

    print("OAuth Token Generated")

    print("=" * 50)
    print("STEP 6 -> STORING IN SECRETS MANAGER")
    print("=" * 50)

    secret_payload = {
        "access_token": oauth_token["access_token"],
        "expires_in": oauth_token["expires_in"],
        "thumbprint": cert_data["thumbprint"]
    }

    store_token_secret(secret_payload)

    print("Stored in AWS Secrets Manager")

    print("=" * 50)
    print("PROCESS COMPLETED SUCCESSFULLY")
    print("=" * 50)

    return {
        "statusCode": 200,
        "body": "SUCCESS"
    }