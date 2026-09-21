# skills

A collection of portable agent skills.

Each skill is a self-contained `SKILL.md` — plain Markdown with YAML
frontmatter — that teaches a coding agent a specific workflow: when to
trigger, what steps to follow, and what output to produce. There is no
runtime, no dependencies, and nothing vendor-specific: any agent that can
read instructions from disk can use them.

## Available skills

| Skill | Description |
|-------|-------------|
| [`commit-message`](skills/commit-message) | Generates emoji-prefixed conventional commit messages from your staged changes. |
| [`gradle-convention-plugin`](skills/gradle-convention-plugin) | Sets up Gradle convention plugins in a `build-logic` included build and migrates modules onto them. |
| [`gradle-module-creator`](skills/gradle-module-creator) | Creates Gradle modules by reusing an Android, Kotlin/JVM, or Kotlin Multiplatform project's existing patterns. |

## Usage

Clone the repo once:

```bash
git clone git@github.com:weslley-campos/skills.git ~/skills
```

Then make the skills visible to your agent. Every agent discovers instructions
one of two ways — a directory it scans, or a file it always reads — so either
symlink into that directory, or reference the skill from that file.

### Claude Code

Symlink into `~/.claude/skills/`, which makes the skill invocable as
`/commit-message`:

```bash
ln -s ~/skills/skills/commit-message ~/.claude/skills/commit-message
```

Edits apply on the next `/reload-skills`. Alternatively install the repo as a
plugin marketplace, which namespaces the command but handles updates for you:

```
/plugin marketplace add weslley-campos/skills
/plugin install commit-message@weslley-skills   # a single skill
/plugin install gradle-module-creator@weslley-skills # module creator plus convention companion
/plugin install skill@weslley-skills            # every skill in this repo
```

### Codex CLI, Gemini CLI and Copilot

These load Markdown instruction files rather than scanning a skills directory,
so reference the skills you want from a file the agent already reads:

```markdown
## Skills

Read and follow the linked file before starting a matching task.

- [commit-message](~/skills/skills/commit-message/SKILL.md) — writing a git
  commit message.
- [gradle-convention-plugin](~/skills/skills/gradle-convention-plugin/SKILL.md)
  — Gradle convention plugins, `build-logic`, deduplicating module config.
- [gradle-module-creator](~/skills/skills/gradle-module-creator/SKILL.md) — adding
  Android, Kotlin/JVM, or Kotlin Multiplatform modules to an existing Gradle build.
```

Which file to put that in:

| Agent | Global | Per-project |
|-------|--------|-------------|
| [Codex CLI](https://developers.openai.com/codex/guides/agents-md) | `~/.codex/AGENTS.md` | `AGENTS.md`, at any directory level |
| [Gemini CLI](https://google-gemini.github.io/gemini-cli/docs/cli/gemini-md.html) | `~/.gemini/GEMINI.md` | `GEMINI.md`, at any directory level |
| [Copilot](https://docs.github.com/copilot/customizing-copilot/adding-custom-instructions-for-github-copilot) | — | `.github/copilot-instructions.md`, `AGENTS.md`, or `.github/instructions/*.instructions.md` |

`AGENTS.md` is the common denominator: Codex and Copilot read it with no
configuration, and Gemini CLI can be pointed at it by setting
`contextFileName` in `.gemini/settings.json`. One file, three agents.

All three load these files hierarchically — a nested file applies to its
subtree and overrides what is above it — so a skill can be scoped to the
project or module that needs it. Copilot goes further with `applyTo`
frontmatter in `.github/instructions/*.instructions.md`, which scopes by glob:

```markdown
---
applyTo: "**/*.gradle.kts"
---
```

### Any other agent

The pattern generalises. Find the directory your agent scans or the file it
always reads, then symlink or reference accordingly:

```bash
ln -s ~/skills/skills/commit-message <agent-skills-dir>/commit-message
```

Symlinking and referencing both beat copying: edits take effect immediately,
and one `git pull` updates every agent at once.

## Adding a skill

Create a directory under `skills/` containing a `SKILL.md`:

```
skills/my-skill/SKILL.md
```

The frontmatter drives discovery. Write the `description` for the model, not
for a human — it is often the only thing an agent reads when deciding whether
the skill applies, so spell out the trigger phrases explicitly:

```markdown
---
name: my-skill
description: >
  What the skill does. Use this skill whenever the user says "...", asks to
  ..., or any variation of requesting ....
---

Instructions for the agent go here.
```

Keep the body portable: describe the workflow and the shell commands to run.
Do not depend on tools, file layouts, or slash commands that only one agent
provides.

### Claude Code plugin manifest

`.claude-plugin/marketplace.json` lets the repo double as a Claude Code plugin
marketplace. It is optional and every other install path ignores it. The
`skill` bundle picks up new directories automatically; to make a skill
installable on its own, add an entry and validate:

```json
{
  "name": "my-skill",
  "description": "What it does",
  "source": "./",
  "strict": false,
  "skills": ["./skills/my-skill"]
}
```

```bash
claude plugin validate .
```
