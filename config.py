import os

# =========================================
# AZURE / ENTRA CONFIG
# =========================================

TENANT_ID = os.environ["TENANT_ID"]

ADMIN_CLIENT_ID = os.environ["ADMIN_CLIENT_ID"]

ADMIN_CLIENT_SECRET = os.environ["ADMIN_CLIENT_SECRET"]

TARGET_CLIENT_ID = os.environ["TARGET_CLIENT_ID"]

# =========================================
# AWS CONFIG
# =========================================

AWS_SECRET_NAME = os.environ["AWS_SECRET_NAME"]

AWS_REGION = os.environ.get("AWS_REGION", "ap-south-1")

# =========================================
# MICROSOFT GRAPH
# =========================================

AUTHORITY = f"https://login.microsoftonline.com/{TENANT_ID}"

GRAPH_SCOPE = [
    "https://graph.microsoft.com/.default"
]

GRAPH_BASE_URL = "https://graph.microsoft.com/v1.0"