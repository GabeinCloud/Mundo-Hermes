# Hermes Manager for Windows

[Español](README.md)

Reproducible configuration and an independent community manager for running [Hermes Agent](https://github.com/NousResearch/hermes-agent) instances with Docker Desktop, without requiring users to write Docker Compose by hand.

> This release does not contain Hermes or any Docker image. Docker downloads the external `nousresearch/hermes-agent` image when it is first needed. This project is not official and is not affiliated with or endorsed by Nous Research.

## Quick start

1. Install and start [Docker Desktop](https://www.docker.com/products/docker-desktop/) with WSL 2.
2. Download `Hermes-Manager-Windows-<version>.zip` from GitHub Releases.
3. Extract the ZIP and double-click `Instalar.cmd`.
4. Press Enter to use the recommended folder or enter another installation folder.
5. Wait for the checks to finish.
6. Open the desktop shortcut and create your first agent.
7. Choose a terminal alias such as `writer` or `dev`.

That is all. The ZIP contains the installer, manager scripts, configuration, documentation and tests. It does not contain Docker Desktop or the Hermes image; Docker downloads that image automatically when the first agent is configured or started.

### Optional download verification

The Release also provides a separate `.sha256` file. It is not required for installation, but it can verify that the downloaded ZIP has not been corrupted or modified:

```powershell
$zip = '.\Hermes-Manager-Windows-<version>.zip'
$expected = ((Get-Content "$zip.sha256") -split '\s+')[0]
$actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
if ($actual -ne $expected) { throw 'The ZIP does not match the published checksum.' }
```

The recommended installation directory is `%LOCALAPPDATA%\HermesManager`, but the installer allows another folder. Python, Git, PowerShell 7 and a host installation of Hermes are not required. Ollama is optional.

Agent identities, credentials, conversations and workspaces stay under `<installation folder>\agents`. Runtime data is excluded from both Git and generated release archives. Docker downloads the configured image during the first setup or start and the update command explicitly pulls a newer copy of that image.

Each generated Compose configuration uses a read-only container filesystem, drops default capabilities, prevents privilege escalation, applies resource limits and publishes no ports. Its private bridge network still allows outbound access for configured providers.

See the step-by-step [GUIA-INSTALACION.md](GUIA-INSTALACION.md), [NOTICE.md](NOTICE.md), [SECURITY.md](SECURITY.md) and [LICENSE](LICENSE).
