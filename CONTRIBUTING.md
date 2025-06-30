# Contributing to TabLift

First off, thanks for taking the time to contribute! Your help makes TabLift better for everyone.

## How to Contribute

We welcome all contributions, including bug reports, feature requests, code, documentation, and design.

### 1. Bug Reports and Feature Requests

- **Search existing issues** before submitting a new one to avoid duplicates.
- If you find a bug, open a [GitHub Issue](https://github.com/turtle-key/TabLift/issues/new) with steps to reproduce, expected behavior, and screenshots if possible.
- If you have a feature idea, describe the use case and possible implementation.

### 2. Pull Requests

- **Fork** the repo and create your branch from `main`:
  ```bash
  git clone https://github.com/turtle-key/TabLift.git
  cd TabLift
  git checkout -b my-feature
  ```
- **Keep your changes focused.** One feature or fix per pull request.
- **Follow the project style:**  
  - Swift: Use [SwiftLint](https://github.com/realm/SwiftLint) conventions where possible.
  - Svelte/TypeScript: Use `prettier` and `eslint` defaults.
- **Test your code** before submitting:  
  - For macOS app changes, build and run in Xcode.
  - For website changes, run `npm run dev` and verify locally.
- **Document** your changes in code and/or in the PR description.
- Reference related issues in your PR (e.g., "Closes #123").

### 3. Commit Messages

- Use clear, descriptive commit messages.
- Example: `Fix: restore minimized windows for all spaces`

### 4. Code Review Process

- PRs are reviewed by maintainers.
- Address all review comments and suggestions.
- Squash or rebase your commits if asked.

### 5. Project Structure

- **macOS app code:** in `Sources/`
- **Website:** in `website/`
- **Images:** in `Images/`
- See [README.md](README.md) for more details.

### 6. Code of Conduct

Be respectful and constructive. See [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) for details.

## Need Help?

Open an [issue](https://github.com/turtle-key/TabLift/issues) or email [ghetumihaieduard@gmail.com](mailto:ghetumihaieduard@gmail.com).

---

Thank you for contributing to TabLift!
