# SeedBot: Minimal, Self-Extensible Personal Assistant

SeedBot is a harness to turn Codex into a simple but extensible personal assistant. It is designed to be as minimal as possible, starting with only **coding** and **terminal input** capability, but can be instructed to build new capability over time.

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


## Notes

Codex is preferred over Claude Code for SeedBot, because:

- Codex shows better reasoning capability to overcome complex logics or ambiguous user requests.
- Codex is more permissive for backend-in-app usage, while Claude Code only allows access-via-API if used as a backend.

SeedBot is a proof-of-concept project to show that coding is the only must-to-have capability for a personal assistant. For robust use of codex, [App Server](https://developers.openai.com/codex/app-server/) is preferred over the current "call over bash" method.
