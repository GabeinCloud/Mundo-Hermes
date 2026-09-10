# Hermes Manager for Windows

[Español](README.es.md)

Reproducible configuration and a community manager for creating Hermes agents with Docker Desktop without writing Docker Compose by hand.

> This project is not official and is not affiliated with Nous Research. The Release does not include Hermes or any Docker image. Docker downloads the external public image `nousresearch/hermes-agent` when it is first needed.

## Why this exists

Running Hermes on Windows involves Docker Desktop, a Compose configuration, persistent agent data and several recurring commands. Hermes Manager brings those pieces together in a small, reproducible workflow: create isolated agents, keep their data separate, configure them through the official assistant and start or update them without writing Docker Compose by hand. It is a community convenience layer around Hermes, not a replacement for Hermes or Docker Desktop.

## Quick installation

### Requirements

- 64-bit Windows 10 or 11.
- Virtualization and WSL 2 enabled.
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running.

You do not need to install Python, Git, PowerShell 7 or Hermes directly on Windows. Ollama is only required for local models.

### From a GitHub Release

1. Download `Hermes-Manager-Windows-<version>.zip` from **Releases**.
2. Extract the ZIP.
3. Double-click `Instalar.cmd`.
4. Press Enter to use the recommended folder or enter another installation folder.
5. Wait for the checks to finish.
6. Open **Hermes Manager** from the desktop shortcut.

That is all. The ZIP contains the installer, scripts, configuration, documentation and manager tests. It does not contain Docker Desktop or the Hermes image: Docker downloads that image automatically when the first agent is configured or started.

The recommended folder is `%LOCALAPPDATA%\HermesManager`, but you can choose another location during installation. Administrator permissions are not required if your user can write to the selected location. The installer adds that installation's `bin` folder to the user `PATH`.

You do not need `git clone` to install or use Hermes Manager. The **Releases** page contains the package prepared for users. The **Source code** ZIP files shown by GitHub contain the repository source and are intended for development, not for the normal installation flow.

The default files use Spanish prompts. English users can run `Install (English).cmd`; it installs the English shortcut **Hermes Manager (English)** and the `hermes-en.cmd` command. Use `Uninstall (English).cmd` for the English uninstall prompts.

#### Optional download verification

The Release also publishes a `.sha256` file. It is not required for installation, but it lets you verify manually that the downloaded ZIP is neither corrupted nor modified. It is published separately because a file cannot verify its own download.

```powershell
$zip = '.\Hermes-Manager-Windows-<version>.zip'
$expected = ((Get-Content "$zip.sha256") -split '\s+')[0]
$actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
if ($actual -ne $expected) { throw 'The ZIP does not match the published checksum.' }
```

## Create your first agent

1. Open `Hermes Manager`.
2. Select **1. Create agent**.
3. Enter its name and purpose.
4. Choose a short terminal alias, such as `writer` or `dev`.
5. Complete the provider and model setup assistant.
6. Start the agent.

When you configure or start the first agent, Docker downloads Hermes from the registry if the image is not already available on the computer. That download is not part of the installer or this repository. Then open a new terminal and enter only the selected alias:

```powershell
writer
```

## Features

- Generate a reproducible Docker Compose configuration for each agent.
- Keep each agent's data separate and publish no ports by default.
- Configure the provider and model with the Hermes setup assistant.
- Start, stop and open conversations.
- Update one agent or all agents.
- Detect local Ollama models.
- Create global aliases without copying scripts outside the installation.
- Move removed agents to a recoverable trash folder.
- Diagnose Docker without exposing secrets.

The generated configuration uses a read-only container filesystem, drops default capabilities, prevents privilege escalation and limits CPU, memory and processes. The Docker network separates agents and allows outbound access to configured providers; it is not an offline network.

## Data and privacy

Each agent stores its identity, configuration, credentials, conversations and documents under `<installation folder>\agents\<name>\data`.

Do not publish or attach that folder to issues. Data, alias, log and trash directories are excluded by both `.gitignore` and the Release generator.

Never commit or upload `agents/`, `bin/`, `logs/`, `trash/`, `.env`, `config.yaml` or `.hermes-manager-install.json`. These paths can contain credentials, conversations, logs or installation-specific data.

See [GUIA-INSTALACION.md](GUIA-INSTALACION.md) for the complete step-by-step configuration, all generated files and instructions for pinning a specific image version or digest.

## Optional commands

```powershell
hermes-manager
# The following examples use the recommended folder:
& "$env:LOCALAPPDATA\HermesManager\hermes.cmd" crear writer
& "$env:LOCALAPPDATA\HermesManager\hermes.cmd" actualizar todos
```

The command names remain in Spanish. Run `hermes ayuda` to display all available commands.

## Updating

- **Update agent** downloads or verifies the digest-pinned image and preserves its data. A new manager release may publish an updated digest.
- To update Hermes Manager, run `Instalar.cmd` from a newer Release and select the same installation folder. The installer replaces only program files.

## Development

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-HermesManager.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tests\Test-PublicPackage.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Build-Release.ps1"
```

## Security and license

See [SECURITY.md](SECURITY.md), [NOTICE.md](NOTICE.md) and [LICENSE](LICENSE). Do not include credentials, agent configurations or logs in public reports.
