# skills

My Agents skills.

## Install

```
/plugin marketplace add weslley-campos/skills
```

Then pick one:

```
/plugin install commit-message@weslley-skills   # just this skill
/plugin install skill@weslley-skills            # everything, as /skill:<name>
```

### Prefer bare `/commit-message`?

Plugin skills are always namespaced (`/skill:commit-message`). For an
unprefixed command, clone and symlink into your personal skills dir instead:

```
git clone git@github.com:weslley-campos/skills.git
ln -s "$PWD/skills/commit-message" ~/.claude/skills/commit-message
```

## Skills

| Skill | What it does |
|-------|--------------|
| [commit-message](skills/commit-message) | Emoji-prefixed conventional commit messages |

## Add a skill

Drop a directory under `skills/` containing a `SKILL.md`:

```
skills/my-skill/SKILL.md
```

With frontmatter:

```markdown
---
name: my-skill
description: What it does and when Claude should use it.
---

Instructions here.
```

The `skill` bundle picks it up automatically. To make it installable on its
own, add an entry to `.claude-plugin/marketplace.json`:

```json
{
  "name": "my-skill",
  "description": "What it does",
  "source": "./",
  "strict": false,
  "skills": ["./skills/my-skill"]
}
```
