---
name: commit-message
description: >
  Create git commits with emoji-prefixed conventional commit messages. Use this skill whenever the
  user asks to commit, make a commit, create a commit message, or says things like "/commit-message",
  "commit this", "commit my changes", "commit what I have", "save my work", or any variation of
  requesting a git commit. Also trigger when the user asks to format a commit message or wants help
  writing one.
---

# Commit Message Skill

Generate a commit message from staged (or all pending) changes and create the commit.

## Workflow

1. Run `git status` and `git diff --cached` (staged changes). If nothing is staged, run `git diff` to see unstaged changes and ask the user if they'd like to stage specific files before committing.
2. Analyze the changes to understand **what** changed and **why** it matters.
3. Pick the single most fitting type from the table below.
4. Present the proposed commit message to the user and ask for confirmation before committing. The user may want to adjust the type, wording, or scope. Only proceed with the commit after the user approves.

## Commit format

```
<emoji> <type>: <Short imperative description>.
```

- **Always English.**
- Subject line only — no body, no footer.
- Use the imperative mood ("Add", "Fix", "Update", not "Added", "Fixes", "Updated").
- Keep the subject under 72 characters (emoji + type + colon + space + description).
- Capitalize the first word of the description.

## Type table

| Emoji | Type       | When to use                                                        |
|:-----:|------------|--------------------------------------------------------------------|
|  ✨   | feat       | A real, user-facing feature — not scaffolding or boilerplate       |
|  🐞   | fix        | Bug fix (PATCH in semver)                                          |
|  ♻️   | refactor   | Code restructuring without changing behavior                       |
|  🎨   | style      | Formatting, whitespace, punctuation — no logic changes             |
|  📚   | docs       | Documentation only (README, comments, etc.)                        |
|  🧪   | test       | Adding or updating tests, no production code changes               |
|  ⚡   | perf       | Performance improvements                                          |
|  🛠️   | build      | Build system or dependency changes                                 |
|  🔄   | ci         | CI/CD configuration changes                                       |
|  ⚙️   | chore      | Maintenance tasks, config tweaks, tooling — no production code     |

When changes span multiple types, pick the **primary intent**. For example, if you add a feature and also write tests for it, use `feat` because the feature is the main point.

Be precise with `feat` — it means a real, working feature that adds value to the user. Scaffolding a new module with placeholder screens, creating boilerplate structure, or generating empty templates is `chore`, not `feat`. Use `feat` only when the commit delivers actual functionality.

## Creating the commit

After writing the message, create the commit using a heredoc to preserve formatting:

```bash
git commit -m "$(cat <<'EOF'
<emoji> <type>: <Description>.
EOF
)"
```
