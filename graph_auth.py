import msal

from config import (
    AUTHORITY,
    ADMIN_CLIENT_ID,
    ADMIN_CLIENT_SECRET,
    GRAPH_SCOPE
)

def get_graph_access_token():

    app = msal.ConfidentialClientApplication(
        client_id=ADMIN_CLIENT_ID,
        authority=AUTHORITY,
        client_credential=ADMIN_CLIENT_SECRET
    )

    result = app.acquire_token_for_client(
        scopes=GRAPH_SCOPE
    )

    if "access_token" not in result:
        raise Exception(
            f"Failed to get Graph token: {result}"
        )

    return result["access_token"]