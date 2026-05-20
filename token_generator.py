import msal

from config import (
    AUTHORITY,
    TARGET_CLIENT_ID,
    GRAPH_SCOPE
)

def generate_token_using_certificate(
    private_key_pem,
    thumbprint,
    public_certificate_pem
):

    client_credential = {
        "private_key": private_key_pem.decode(),
        "thumbprint": thumbprint,
        "public_certificate": public_certificate_pem.decode()
    }

    app = msal.ConfidentialClientApplication(
        client_id=TARGET_CLIENT_ID,
        authority=AUTHORITY,
        client_credential=client_credential
    )

    result = app.acquire_token_for_client(
        scopes=GRAPH_SCOPE
    )

    if "access_token" not in result:
        raise Exception(
            f"Token generation failed: {result}"
        )

    return result