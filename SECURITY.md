# Open Android DeX — Security Policy

For the complete threat model and security specifications, please refer to [`docs/SECURITY.md`](docs/SECURITY.md).

## Reporting a Vulnerability

If you discover a security vulnerability in Open Android DeX, please report it privately rather than creating a public issue.

* **Email:** `security@bitmanipulators.org` (or submit a private GitHub Security Advisory)
* **Response Time:** We aim to acknowledge reports within 48 hours and coordinate a patched release prior to public disclosure.

## Security Practices for Contributors

1. Never commit credentials, private keys, or tokens.
2. In Android companion services, never bind sockets to `0.0.0.0` (bind strictly to `127.0.0.1` loopback).
3. In Python, avoid `shell=True` in `subprocess` calls. Always pass arguments as a list.
4. Named pipes and temporary files must reside in secure, user-restricted directories (`$XDG_RUNTIME_DIR/opendex/`).
