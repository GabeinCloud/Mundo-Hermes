# Public installation guide

This guide installs and operates Hermes Manager on another Windows computer. The repository and release package contain only the manager, documentation, and the template used to generate Docker Compose files. They do not contain Hermes Agent, Docker images, models, or agent data.

## 1. Install Docker Desktop

1. Download Docker Desktop from <https://www.docker.com/products/docker-desktop/>.
2. Install it with the WSL 2 backend.
3. Restart Windows if requested.
4. Open Docker Desktop and wait until the engine is ready.

## 2. Install Hermes Manager

1. Download `Hermes-Manager-Windows-<version>-en.zip` from GitHub Releases.
2. Extract the ZIP.
3. Double-click `Install.cmd` inside the extracted folder.
4. Press Enter to install under `%LOCALAPPDATA%\HermesManager`, or enter another folder.
5. Wait for the installation checks to finish.
6. Open **Hermes Manager** from the desktop shortcut.

You do not need to clone the repository. GitHub's **Source code** downloads are development snapshots and are not the prepared installer.

The destination must be empty or contain a recognized Hermes Manager installation. Administrator rights are not required when your user can write to the selected location. The installer creates `agents`, `bin`, `logs`, and `trash`, adds `bin` to the user `PATH`, and creates the shortcut. It does not install Docker or modify the system `PATH`.

### Optional verification

Download the matching `.sha256` file next to the ZIP and run:

```powershell
$zip = '.\Hermes-Manager-Windows-<version>-en.zip'
$expected = ((Get-Content "$zip.sha256") -split '\s+')[0]
$actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
if ($actual -ne $expected) { throw 'The ZIP does not match the published checksum.' }
'Checksum verified'
```

## 3. Create an agent

1. Choose **Create agent**.
2. Enter its name and purpose.
3. Accept or change the suggested terminal alias.
4. Configure the provider and model through the official Hermes Agent assistant.
5. Start the agent.

Docker downloads the approved `nousresearch/hermes-agent` image when it is first needed. The reference is pinned by digest so its content cannot change without an explicit Hermes Manager update.

## 4. Generated files

Each agent is stored under `<installation folder>\agents\<name>`:

| Path | Contents |
| --- | --- |
| `compose.yaml` | Reproducible container configuration. |
| `agent.json` | Name, purpose, creation time, language, and alias. |
| `data\SOUL.md` | Agent identity and working instructions. |
| `data\.env` | Container variables; may contain sensitive data. |
| `data\config.yaml` | Configuration created by Hermes, when applicable. |
| `data\home` | Persistent home directory. |
| `data\workspace` | Persistent documents and work. |
| `data\logs` | Agent logs. |

Never upload `agents/`, `bin/`, `logs/`, `trash/`, `.env`, `config.yaml`, or `.hermes-manager-install.json`. They may contain credentials, conversations, logs, or computer-specific paths.

The generated container uses a read-only filesystem, one writable `data` volume, `no-new-privileges`, reduced capabilities, process/CPU/memory limits, and no published ports. Its bridge network allows outbound connections required by providers and is not an offline network.

## 5. Image selection

The image is configured in `<installation folder>\settings.json` and must end with a SHA-256 digest:

```json
"hermes_image": "nousresearch/hermes-agent@sha256:41b9ed005cebcb3d3fb45206ce27cfb0356ba99b190c0924bab5141b15ad8e71"
```

**Update agent** downloads or verifies the configured image. A later Hermes Manager release may publish a newly verified digest. Before changing this setting manually, verify the image and digest through the upstream project.

## 6. Terminal use

Open a new terminal after installation and type the alias selected for the agent. Hermes Manager rejects reserved aliases and aliases that conflict with existing commands.

The manager itself can also be opened with:

```powershell
hermes-manager-en
```

Run `hermes-en.cmd help` inside the installation folder to list English commands.

## 7. Local models

Install and open Ollama on Windows. Hermes Manager detects models through `http://localhost:11434`; containers connect through `http://host.docker.internal:11434`.

## 8. Updates, backup, and uninstall

To update an agent, choose **Update agent**. To update Hermes Manager, download a newer English Release, run `Install.cmd`, and select the same installation folder. Agent data is preserved.

Before uninstalling, stop agents and back up the `agents` folder. Run `Uninstall.cmd`. By default, it removes the shortcut and user `PATH` entry but keeps the installation and agent data. Full deletion requires `-RemoveAllData` and two explicit confirmations.

## 9. Troubleshooting

- **Docker not found:** install Docker Desktop and open it at least once.
- **Engine stopped:** open Docker Desktop and wait until it is ready.
- **Alias not recognized:** open a new terminal or run `Activate global aliases.cmd`.
- **Wrong provider or model:** choose **Configure provider/model**.
