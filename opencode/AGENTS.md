# Global Instructions

## Communication

- Be concise, direct, and factual.
- State what you are doing before substantial work.
- Explain important decisions and tradeoffs briefly.
- Report verification results and mention tests or checks that were not run.
- Do not stop at a proposed solution when implementation is requested.

## Repository Workflow

- Inspect the repository and its existing conventions before making changes.
- Prefer the smallest correct change.
- Follow established project patterns instead of introducing new ones unnecessarily.
- Preserve unrelated user changes in the worktree.
- Keep scope limited to the requested task.

## Editing

- Avoid unnecessary abstractions, dependencies, compatibility layers, and comments.
- Add comments only when they explain non-obvious behavior or constraints.
- Do not rewrite or reformat unrelated code.
- Treat generated files and symlinks according to the project's existing conventions.

## Verification

- Run the most relevant focused tests, linters, formatters, or build checks after changes.
- Prefer targeted verification first, followed by broader checks when practical.
- Never claim that a check passed unless it was actually run.

## Git And Safety

- Inspect `git status` and relevant diffs before and after changes.
- Never use destructive commands such as `git reset --hard`, `git checkout --`, or `git clean` unless explicitly requested.
- Do not commit, amend, push, or alter git configuration unless explicitly requested.
- When committing is explicitly requested, use a terse, one-line message with a lowercase first word by default.
- Do not add a verbose commit body, description, or co-authored attribution.
- Do not overwrite or revert changes made by the user.
- Quote shell paths, especially paths containing spaces.
- Prefer safe, reviewable file edits over ad-hoc shell redirection.

## User Preferences

- Favor correctness, maintainability, security, and portability.
- Preserve existing UI and design-system patterns in frontend work.
- Ensure frontend changes work on desktop and mobile.
- Update relevant documentation when behavior or setup changes.
