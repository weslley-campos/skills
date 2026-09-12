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

## Usage

Clone the repo once:

```bash
git clone git@github.com:weslley-campos/skills.git ~/skills
```

Then make the skills visible to your agent. Every agent discovers
instructions somewhere — a directory it scans, or a file it always reads.
Symlink into the former, or reference from the latter.

**Symlink into a directory the agent scans:**

```bash
ln -s ~/skills/skills/commit-message <agent-skills-dir>/commit-message
```

**Or reference from the always-read instructions file** (`AGENTS.md`,
`CLAUDE.md`, or equivalent):

```markdown
## Skills

- [commit-message](~/skills/skills/commit-message/SKILL.md) — read and follow
  this when asked to commit.
```

Symlinking and referencing both beat copying: edits to the repo take effect
immediately, and one `git pull` updates every agent at once.

### Agent-specific notes

**Claude Code** — symlink into `~/.claude/skills/` to invoke a skill as
`/commit-message`; edits apply on the next `/reload-skills`. The repo also
ships a plugin manifest, so it can be installed as a marketplace instead:

```
/plugin marketplace add weslley-campos/skills
/plugin install commit-message@weslley-skills   # a single skill
/plugin install skill@weslley-skills            # every skill in this repo
```

Plugin skills are namespaced, so they are invoked as
`/commit-message:commit-message` or `/skill:commit-message`.
