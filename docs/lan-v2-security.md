# LAN v2 security and compatibility record

Sources checked before implementation:

- https://www.rfc-editor.org/rfc/rfc8446 — TLS 1.3 record sequencing, AEAD associated data and nonce discipline.
- https://www.rfc-editor.org/rfc/rfc7748 — X25519 key agreement.
- https://datatracker.ietf.org/doc/rfc8439/ — ChaCha20-Poly1305 AEAD construction.
- https://pub.dev/packages/cryptography — cryptography 2.9.0 package/API documentation.
- https://pub.dev/documentation/cryptography/2.9.0/ — X25519, Hkdf, Xchacha20.poly1305Aead and SecretBox APIs.

The locked dependency is cryptography 2.9.0. The runtime uses its documented X25519, HKDF-SHA-256 and XChaCha20-Poly1305 APIs; no primitive is implemented locally.

## Wire profile

The client and server exchange signed, per-session ephemeral X25519 public keys and 32-byte nonces. HKDF derives 96 bytes from the shared secret, both nonces and the canonical handshake transcript. The material is split into independent client-write/server-write keys and 16-byte nonce prefixes.

Every application payload is an AEAD record. The clear header contains only version, sequence and cipher-suite fields plus ciphertext. The operation, request ID, URLs, cookies, history and image metadata are encrypted. Each direction starts at sequence zero and accepts only the next sequence; replay, reordering, gaps, bad MACs and wrong versions are rejected.

Nonce lifecycle: ephemeral X25519 keys are destroyed after derivation, traffic keys are destroyed on session close, and the nonce is prefix concatenated with a big-endian 64-bit sequence. Sequence exhaustion requires a new handshake.

## Compatibility boundary

Version 1 records remain representable for migration tests, but the session endpoint rejects v1 with LAN_PROTOCOL_UPGRADE_REQUIRED. No v1 token, URL, gallery or image request is accepted. New clients offer versions 2 and 1 but require a v2 response.

The existing HTTP pairing flow remains the bootstrap/migration boundary and carries a one-time token on the trusted local network. After pairing, the token is sent only inside the v2 AEAD session.
