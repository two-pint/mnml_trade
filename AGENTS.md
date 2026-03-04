# Agent Instructions

## Requesting Permission to Run Commands

When requesting permission to run a command, always include a brief explanation of **why** the command needs to be run — not just what it does. The user should understand the purpose and necessity before approving.

- State the goal the command achieves in the current context
- Explain what would happen (or fail to happen) without it
- If the command has side effects (writes files, installs packages, modifies config), mention them

Bad: "Can I run `pnpm install`?"
Good: "Can I run `pnpm install`? This is needed to pull in the new `@mnml/ui` dependency we just added to `package.json`, so the app can resolve the shared component imports."
