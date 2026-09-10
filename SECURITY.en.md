# Security policy

## Supported versions

Only the latest published version receives security fixes.

## Reporting a vulnerability

Do not open a public issue containing keys, `.env` files, `config.yaml`, conversations, complete logs, or personal data. Use the repository's private GitHub security reporting channel.

Include only the Hermes Manager version, Windows and Docker Desktop versions, minimal reproduction steps, impact, and redacted logs.

## Security model

- Releases do not contain Docker images. Docker downloads the configured external image when needed.
- The default `nousresearch/hermes-agent` image is pinned to a verified OCI digest.
- Agents use a read-only container filesystem, reduced capabilities, process and resource limits, and `no-new-privileges`.
- The Docker socket is not mounted inside agents.
- No ports are published by default.
- The bridge network permits outbound connections to configured providers and services; it does not isolate agents from the Internet.
- Persistent data remains inside the installation folder.
- The container image can read and modify the agent's `data` directory, including configured credentials.
- Release generation rejects runtime data and container image exports.

Hermes Manager cannot protect credentials that a user copies, publishes, or grants to third-party tools. Rotate any exposed credential immediately.
