# ĐÌNH ĐƯỢC- VOICE STUDIO: machine activation

Owner tool: `issuer/`. RSA-3072 signing keys are generated **on the owner's
Windows computer**, stored with Windows DPAPI CurrentUser, and never committed
or included in distributed ZIPs. The owner exports only `DINH-DUOC-PUBLIC-KEY.json`.

Client verifier: `device-license.ts`. The client build must pin that public key;
there is no user-selectable trust key or shared signing password. Signed claims
include product, issuer key ID, machine code, issued-at time, expiration and nonce.
Expiry starts at issuance. Optional perpetual codes have a signed null expiry.

The build of the branded client awaits the owner's public key. Do not distribute
a client build without a pinned authority. The owner's key manager is a separate
tool, not part of the friends' app.

Offline expiry depends on the machine clock. Last-seen time and issuance checks
can detect ordinary clock rollback; an offline open-source client cannot promise
tamper-proof enforcement or remote revocation. Upstream AGPL obligations and
individual voice-model licenses remain applicable.
