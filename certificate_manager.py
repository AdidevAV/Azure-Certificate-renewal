from cryptography import x509

from cryptography.x509.oid import NameOID

from cryptography.hazmat.primitives import (
    hashes,
    serialization
)

from cryptography.hazmat.primitives.asymmetric import rsa

from datetime import datetime, timedelta

def generate_self_signed_certificate():

    private_key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048
    )

    subject = issuer = x509.Name([
        x509.NameAttribute(
            NameOID.COMMON_NAME,
            u"LambdaGeneratedCertificate"
        )
    ])

    certificate = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(issuer)
        .public_key(private_key.public_key())
        .serial_number(
            x509.random_serial_number()
        )
        .not_valid_before(
            datetime.utcnow()
        )
        .not_valid_after(
            datetime.utcnow() + timedelta(days=365)
        )
        .sign(
            private_key,
            hashes.SHA256()
        )
    )

    # =====================================
    # PUBLIC CERTIFICATE
    # =====================================

    cert_pem = certificate.public_bytes(
        serialization.Encoding.PEM
    )

    cert_der = certificate.public_bytes(
        serialization.Encoding.DER
    )

    # =====================================
    # PRIVATE KEY
    # =====================================

    private_key_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption()
    )

    # =====================================
    # THUMBPRINT
    # =====================================

    thumbprint = certificate.fingerprint(
        hashes.SHA1()
    ).hex()

    return {
        "cert_pem": cert_pem,
        "cert_der": cert_der,
        "private_key_pem": private_key_pem,
        "thumbprint": thumbprint
    }