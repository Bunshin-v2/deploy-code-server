```markdown
# deploy-code-server Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill teaches the development patterns and conventions used in the `deploy-code-server` TypeScript repository. It covers file organization, code style, commit patterns, and testing strategies. By following these guidelines, contributors can maintain consistency and quality across the codebase.

## Coding Conventions

### File Naming
- **Pattern:** PascalCase
- **Example:**  
  `DeployManager.ts`, `UserSessionHandler.ts`

### Import Style
- **Pattern:** Relative imports
- **Example:**
  ```typescript
  import { startServer } from './ServerUtils';
  ```

### Export Style
- **Pattern:** Named exports
- **Example:**
  ```typescript
  // In DeployManager.ts
  export function deploy() { ... }
  export const DEPLOY_TIMEOUT = 3000;
  ```

### Commit Patterns
- **Style:** Conventional commits
- **Prefix:** `fix`
- **Example:**
  ```
  fix: resolve server crash on invalid config
  ```

## Workflows

### Fixing a Bug
**Trigger:** When you need to resolve a bug or issue in the codebase  
**Command:** `/fix-bug`

1. Identify the bug and its root cause.
2. Create a new branch for your fix.
3. Apply the fix using TypeScript and follow coding conventions.
4. Write or update tests in a `*.test.*` file to cover the fix.
5. Commit your changes using the `fix:` prefix.
   ```
   fix: correct error handling in DeployManager
   ```
6. Push your branch and open a pull request.

### Adding a New Feature
**Trigger:** When implementing a new feature  
**Command:** `/add-feature`

1. Plan the feature and its impact on existing code.
2. Create a new branch for the feature.
3. Add new files using PascalCase naming.
4. Use relative imports and named exports for new modules.
5. Write or update tests to cover the new feature.
6. Commit with a descriptive message (use a relevant conventional prefix if possible).
7. Push and open a pull request.

## Testing Patterns

- **Framework:** Unknown (no specific framework detected)
- **Test File Pattern:** Files named with `*.test.*`
- **Example:**
  ```
  DeployManager.test.ts
  ```
- **Typical Test Structure:**
  ```typescript
  import { deploy } from './DeployManager';

  describe('deploy', () => {
    it('should deploy successfully', () => {
      // test logic here
    });
  });
  ```

## Commands
| Command      | Purpose                                   |
|--------------|-------------------------------------------|
| /fix-bug     | Start the bug fixing workflow             |
| /add-feature | Start the new feature implementation flow |
```
