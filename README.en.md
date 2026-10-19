<!-- Author: Ruslan_A7 (RA7). Developed by RA7 with Codex (GPT-6), OpenAI. Created using AILang. License: https://ra7.iuid.cc/LICENSE. -->
# AILang

[Українська](README.md) · **English**

From an author's idea to software that preserves its meaning.

![AILang — a bridge between human language and software code](.Результат/Медіа/ailang-banner-neural.png)

**Current version: 0.6.3 · Ukrainian working specification · before the first stable release.**

AILang is a set of instructions, specifications, and rules that help AI agents correctly interpret software descriptions written in natural language and implement the author's intent using an appropriate technology stack.

The author describes the software itself in `.Джерело` (the English name for this directory role is `.Source`). AILang tells the agent how to read that description, clarify ambiguities, work with requirements, settings, and permissions, and check whether the result matches the intent. Different agents may produce different implementations; the goal is to preserve the substance of the author's idea as accurately as possible.

## What AILang provides

- Natural-language descriptions of desired behavior in Markdown.
- Separation of author-owned sources, output, documentation, and tools.
- Explicit requirements, stable IDs, and traceability from source to output to verification.
- Per-project settings for language, technology, attribution, Git, and permissions.
- A review of settings after changes, with agreement on any necessary migration.
- Rules for security, privacy, dependencies, and preserving development context.

[Getting started](.Результат/uk/Початок.md) · [Agent instructions](.Результат/uk/Інструкції/Agents.md) · [Overview](.Документація/Огляд.md) · [Plan](.План/План.md)

The linked specification and detailed documentation are currently in Ukrainian. This English README introduces the project; an English instruction package is planned for a later release.

## Get started

1. Copy the **contents** of `.Результат/uk` into an `.AILang` directory in your project. Do not create a `uk` subdirectory inside `.AILang`.
2. In your root `AGENTS.md`, link to `.AILang/Інструкції/Agents.md` and instruct the agent to read it before starting work.
3. Review the configuration templates in the package. Set your project's languages, stack, attribution, license, permissions, and Git policy.
4. Describe your software in the source directory whose name is defined by your language settings.
5. Ask the agent to read AILang, the settings, and the source. Initial structure creation is an explicit exception to the rules; subsequent changes to protected author-owned materials require appropriate permission.

For example, an author's Markdown description might begin like this:

```markdown
# Personal task list

Idea: help the user plan their day.

- **TASK-01: the user can add a task with a title.**
- **TASK-02: completed tasks can be hidden using a separate toggle.**
- TASK-01 acceptance criterion: after confirmation, the new task appears in the list.
```

This is an example of a requirements description. The agent selects the implementation, file formats, and checks according to the agreed stack and settings. This repository's author and license settings are not automatically applied to your product.

## Repository contents

| Path | Purpose |
| --- | --- |
| `.Ідея` | Original author-owned materials |
| `.Джерело` | Description of AILang's own development |
| `.Результат/uk` | Current Ukrainian instruction package |
| `.Результат/Медіа` | Logo and splash artwork |
| `.Налаштування` | Settings for this project |
| `.Документація` and `.План` | Implementation documentation, requirements, and continuation notes |
| `.Інструменти/Автоматизація` | Windows scheduler for Codex |

This repository develops AILang itself, so it has no root `.AILang` directory. In projects using AILang, that directory contains one selected localization. Other instruction-package translations are planned after completion of the first Ukrainian version. The repository paths above retain their actual Ukrainian names.

## Codex scheduler for Windows

Launch [Показати таймери.cmd](.Інструменти/Автоматизація/Показати%20таймери.cmd). It requires Windows PowerShell 5.1 with WPF and an installed, authenticated Codex CLI supporting `queue` and app-server.

The scheduler provides a manual timer, a **05:05 (5 hours 5 minutes)** cycle, custom prompts, prompt history, a **«Надіслати зараз» (Send now)** button, quota checks, and a decision log. The session UUID persists between launches; the chat name appears alongside it when Codex provides one. The **Codex.exe…** button lets you select the CLI executable if needed. The scheduler's interface is currently Ukrainian.

Sending starts only after the corresponding user action. Send now uses manual approvals. Unknown quotas block delivery, and low quotas are subject to the configured thresholds. Acceptance by `queue` means that the prompt was accepted, not that the agent has completed its work.

The UUID, chat name, history, and log are stored only in the local, Git-ignored `.Стан` directory. Do not put secrets in prompts.

[Detailed guide](.Документація/Автоматизація.md) · [Script compatibility](.Документація/Сумісність-скриптів.md)

## Development status

The modular Ukrainian core, configuration templates, conformance, security and attribution rules, and supporting automation are implemented. The specification is still evolving. Complete end-to-end examples, a GitHub Pages website, other instruction-package localizations, and materials for release 1.0.0 remain on the roadmap.

## Attribution and license

Idea author: **Ruslan_A7 (RA7)**. Developed with **Codex (GPT-6), OpenAI**, using AILang. Artwork was created with ImageGen; see the [design notes and prompts](.Документація/Бренд.md).

Terms of use: [RA7 Open Free License](https://ra7.iuid.cc/LICENSE).
