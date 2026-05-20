import requests
import base64

from config import GRAPH_BASE_URL

def get_application_by_client_id(
    access_token,
    client_id
):

    headers = {
        "Authorization": f"Bearer {access_token}"
    }

    url = (
        f"{GRAPH_BASE_URL}/applications"
        f"?$filter=appId eq '{client_id}'"
    )

    response = requests.get(
        url,
        headers=headers
    )

    response.raise_for_status()

    data = response.json()

    if not data["value"]:
        raise Exception(
            "Application not found"
        )

    return data["value"][0]

def upload_certificate_to_application(
    access_token,
    application_object_id,
    cert_der_bytes,
    display_name
):

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }

    cert_base64 = base64.b64encode(
        cert_der_bytes
    ).decode("utf-8")

    payload = {
        "keyCredentials": [
            {
                "type": "AsymmetricX509Cert",
                "usage": "Verify",
                "key": cert_base64,
                "displayName": display_name
            }
        ]
    }

    url = (
        f"{GRAPH_BASE_URL}/applications/"
        f"{application_object_id}"
    )

    response = requests.patch(
        url,
        headers=headers,
        json=payload
    )

    response.raise_for_status()

    return True