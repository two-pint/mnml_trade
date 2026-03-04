# Claude Instructions

## Before Asking for Action

Before asking the user to run a command, install a package, or take any manual step, always explain:

- **What** the command/package does
- **Why** it is needed for the current task

When adding a package/dependency, explain:

- What the package does (its purpose and functionality)
- Why this specific package is being added (what problem it solves in context)
- A link to its documentation so the user can review it if needed

Example: instead of "add `corsica` to your deps", say "add `corsica`, a plug-based CORS middleware library, to handle
cross-origin request headers — needed because the frontend on port 3000 and mobile app on port 8081 are different
origins from the API. Docs: https://hexdocs.pm/corsica".