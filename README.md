# SeedBot: Minimal, Self-Extending Personal Assistant

SeedBot is a lightweight harness to turn Codex into a self-extending personal assistant. It is designed to be as minimal as possible, starting with only **coding** and **terminal input** capability, but can be instructed to build new capability over time.

SeedBot is inspired by [OpenClaw](https://github.com/openclaw/openclaw) and [nanobot](https://github.com/HKUDS/nanobot).

SeedBot has **under 100 lines of bash code**.

## Prerequisite

- Preconfigured Codex cli (GPT-5.3-Codex preferred)
- Mac/Linux/WSL with bash environment

## How to run
To start the assistant, simply run:
```bash
./main.sh
```

If you like the assistant you "trained" over time, use the following command to checkpoint it for distribution:
```bash
echo "pack the current non-git-tracked files, with corresponding git commit, into my_assistant.tar for distribution. Remember to mask out the sensitive variables and keep non-sensitive variables in env.sh and don't pack files under logs" | codex exec --full-auto --skip-git-repo-check -
```

## Examples

<table align="center">
  <tr align="center">
    <th><p align="center">Setting Alarms</p></th>
    <th><p align="center">Telgram Message</p></th>
    <th><p align="center">System Control</p></th>
  </tr>
  <tr>
    <td align="center"><p align="center"><img src="assets/alarm.png" width="240" height="400"></p></td>
    <td align="center"><p align="center"><img src="assets/telegram.png" width="240" height="400"></p></td>
    <td align="center"><p align="center"><img src="assets/sudo.png" width="240" height="400"></p></td>
  </tr>
  <tr>
    <td align="center">SeedBot can build cron-like functionality and set alarms</td>
    <td align="center">SeedBot can build Telegram interface and talk to you beyond terminal</td>
    <td align="center">`sudo -v` gives SeedBot temporary admin access, allowing system access like sending you a desktop notification or even read/control your screen. <strong> Use it at your own risk! </strong> </td>
  </tr>
</table>


## Notes

Codex is preferred over Claude Code for SeedBot, because:

- Codex shows better reasoning capability to overcome complex logics or ambiguous user requests.
- Codex is more permissive for backend-in-app usage, while Claude Code only allows access-via-API if used as a backend.

SeedBot is a proof-of-concept project to show that coding is the only must-to-have capability for a personal assistant. For robust use of codex, [App Server](https://developers.openai.com/codex/app-server/) is preferred over the current "call over bash" method.
