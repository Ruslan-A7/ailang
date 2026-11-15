<!--
Author: Ruslan_A7 (RA7).
Developer: Codex (GPT-6.1 Sol) від OpenAI під управлінням RA7.
Created using AILang.
License: RA7 Open Free License — https://ra7.iuid.cc/LICENSE.
-->
# AILang

[Українська](README.md) · **English**

From an author's idea to software that preserves its meaning.

![AILang — neural-network logo and language name](.Результат/Медіа/ailang-banner-neural.png)

**Project version: 0.9.0** · [VERSION](VERSION)

AILang is a set of instructions, specifications, and rules that help AI agents interpret natural-language software descriptions and implement the author's intent using an appropriate technology stack. Implementations may differ between agents; the goal is to preserve the meaning of the author's requirements as accurately as possible.

**AILang itself is already in [.Джерело](.Джерело/AGENTS.md).** Agents read these author-written Markdown files directly. No separately generated instruction package is needed.

[Entry instructions](.Джерело/AGENTS.md) · [AILang contents](.Джерело/AILang.md) · [Settings](.Джерело/.Налаштування/Налаштування.ail.md) · [Plan](.План/План.md)

The linked rules and detailed documentation are currently in Ukrainian.

**[Website and documentation](.Результат/Сайт/en/index.html)** · [New-project starter ZIP](.Результат/Сайт/downloads/ailang-0.9.0-uk-starter.zip) · [Website archive for your server](.Результат/Публікація/ailang-site-0.9.0.zip)

The starter ZIP includes `.AILang/.Джерело`, a root `AGENTS.md` template, and the new project's directories. Extract it into an empty folder and follow `ПОЧАТОК.md`. See the [deployment guide](.Документація/Сайт.md) for uploading the website to your server.

## Get started

1. Create an `.AILang` directory in your project.
2. Copy **the entire `.Джерело` directory from this repository** into it, including the hidden `.Інструкції` and `.Налаштування` directories. The resulting entry path must be `.AILang/.Джерело/AGENTS.md`.
3. In your project's root `AGENTS.md`, instruct the agent to read `.AILang/.Джерело/AGENTS.md`, the main `AILang.md`, and the linked rules.
4. Fill in `.AILang/.Джерело/.Налаштування/Налаштування.ail.md`: attribution, languages, stack, platforms, permissions, Git, and quotas. `Налаштування (зразок).ail.md` is an example, not the active configuration.
5. Describe **your product** using `.ail` or `.ail.md` files in your project's root `.Джерело` directory, and place ideas and context in `.Ідея`. Ask the agent to read them, prepare a plan, and implement the agreed requirements.

`.AILang/.Джерело` contains language rules; your project's root `.Джерело` contains your product description. System directory names depend on language settings.

Author-owned materials are protected under AILang rules: `.Ідея` is read-only for agents; editing `.Джерело` is prohibited by default but can be enabled through settings. Existing instructions in the installed `.AILang` are protected, with a defined exception for settings. The agent creates the resulting program code in the output directory.

## Repository contents

| Path (English equivalent) | Actual repository path | Purpose |
| --- | --- | --- |
| `.Idea` | `.Ідея` | Author-owned context |
| `.Source` | `.Джерело` | AILang itself: entry files, rules, and settings |
| `.Result/Media` | `.Результат/Медіа` | Selected logo and splash artwork |
| `.Result/Site` | `.Результат/Сайт` | Static website, documentation, and downloads |
| `.Result/Publication` | `.Результат/Публікація` | Website archive for server deployment |
| `.Result/<language code>` | `.Результат/<language code>` | Future localized AILang editions |
| `.Site` | `.Сайт` | Website styling and build sources |
| `.Doc` | `.Документація` | Overview and visual identity |
| `.Plan` | `.План` | Current status, questions, and next steps |
| `.Dependencies` | `.Залежності` | Source-file relationships |
| `VERSION` | `VERSION` | Current project version |

English paths are localized equivalents; use the actual Ukrainian paths in this repository.

## Autonomous work

The [quota and automation rules](.Джерело/.Інструкції/Ліміти%20та%20автоматизація.ail.md) specify waiting until the five-hour quota resets plus 1 minute, checking again, and continuing until the weekly threshold. The agent uses the waiting and quota-reading capabilities available in its environment. An instruction to work until the standard limit means stopping at the first threshold. Shutting down the device requires a separate explicit instruction.

## Development

The Ukrainian rules are available for direct use. The website has Ukrainian and English interfaces; its documentation reproduces the original Ukrainian rules. Planned work includes language editions in `.Результат/en`, `.Результат/de`, `.Результат/fr`, and `.Результат/es`, examples, a framework, and VSCode extensions.

## Attribution and license

Author: **Ruslan_A7 (RA7)**. Розробник: **Codex (GPT-6.1 Sol) від OpenAI під управлінням RA7**. Language attribution is recorded in [.Джерело/AILang.md](.Джерело/AILang.md). Artwork was created with ImageGen; see the [design notes and prompts](.Документація/Бренд.md).

Created using AILang. © 2026 AILang. [RA7 Open Free License](https://ra7.iuid.cc/LICENSE).
