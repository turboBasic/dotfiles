---
name: chezmoi
description: Answer chezmoi questions using the local documentation corpus at docs/chezmoi. Use when the user asks anything about chezmoi commands, templates, configuration, source attributes, encryption, or password manager integrations.
---

Answer the user's chezmoi question using the local documentation corpus.

Steps:
1. Read `docs/chezmoi/CLAUDE.md` to orient.
2. Identify which files are relevant to the question.
3. Read those files directly.
4. Answer based on what you read — do not rely solely on training knowledge.

If the question is about a specific CLI command, read `docs/chezmoi/reference/commands/<command>.md`.
If it is about a template function, read `docs/chezmoi/reference/templates/functions/<function>.md`.
If it is about source file naming, read `docs/chezmoi/reference/source-state-attributes.md`.
If it is about configuration, read the relevant file under `docs/chezmoi/reference/configuration-file/`.

The question to answer: $ARGUMENTS
