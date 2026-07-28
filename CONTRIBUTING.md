## 1. How to Contribute Guide

**File:** `CONTRIBUTING.md` (place in the root of the repository)

```markdown
# How to Contribute to Moove Education Platform Documentation

Thank you for contributing to the Moove Education Platform documentation project. This guide outlines the workflow, standards, and best practices for all team members.

## 1. Code of Conduct
All contributors must adhere to professional standards. Respect confidentiality, do not share sensitive information, and follow the security guidelines outlined in the `Security` documentation.

## 2. Getting Started

### 2.1 Prerequisites
- A GitHub account with access to the `moove-openedx-docs` repository.
- Git installed locally.
- A LaTeX distribution (TeX Live or MikTeX) for building documents locally (optional).
- For screenshot editing: Figma (recommended), Adobe Photoshop, or GIMP (see *Tools* section).

### 2.2 Cloning the Repository
```bash
git clone git@github.com:Moove-Digital-Solutions/moove-openedx-docs.git
cd moove-openedx-docs
```

## 3. Branching Strategy
- **`main`** – Production-ready documentation. Direct commits are not allowed.
- **Feature branches** – For all changes. Name them descriptively:
  - `feature/update-screenshot-[image-name]` (e.g., `feature/update-screenshot-dashboard`)
  - `feature/fix-typo-sdd`
  - `feature/add-new-requirements`

## 4. Workflow

### 4.1 Creating a New Branch
```bash
git checkout main
git pull origin main
git checkout -b feature/your-branch-name
```

### 4.2 Making Changes
- **For LaTeX**: Edit the `.tex` files directly. Build locally to verify (run `./build.sh`).
- **For Screenshots**: Edit images in your preferred tool, ensuring adherence to the `BRANDING_GUIDE.md`.
- **For Diagrams**: Edit the `.puml` files in `plantuml/` and regenerate `.png` files if needed.

### 4.3 Commit Conventions
Write clear, concise commit messages:
```
[Component] Short description of change

- Bullet points explaining details (if necessary)
```
Examples:
```
[Screenshots] Annotate dashboard.png with step indicators

- Added numbered callouts for key UI elements
- Blurred out test user email
```
```
[SDD] Update system architecture diagram to include Meilisearch
```

### 4.4 Pull Request (PR) Process
1. Push your branch:
   ```bash
   git push -u origin feature/your-branch-name
   ```
2. Open a Pull Request on GitHub against the `main` branch.
3. Fill out the PR template (provide a summary, checklist, and screenshots if applicable).
4. Request at least one reviewer.
5. Address all feedback.
6. Merge using **Squash and Merge** to keep the history clean.

## 5. Quality Checklist
Before submitting a PR, ensure:
- [ ] LaTeX documents compile without errors.
- [ ] All screenshots follow the `BRANDING_GUIDE.md`.
- [ ] Screenshots do **not** contain sensitive data (emails, passwords, real names). Blur them.
- [ ] Diagrams are up-to-date and match the current system state.
- [ ] Links are valid and point to the correct sections.

## 6. Tools

| Task | Recommended Tool | Notes |
|------|------------------|-------|
| LaTeX Editing | VS Code + LaTeX Workshop, TeXstudio | Ensure `latexmk` is installed |
| Screenshot Annotation | **Figma** (free) | Use the Moove Figma template (see BRANDING_GUIDE) |
| UML/Diagrams | PlantUML (VS Code extension) | Edit `.puml`, generate `.png` |
| Scripts | Bash | Test scripts before committing changes |

## 7. Getting Help
- For LaTeX issues: Ask in the `#documentation` channel.
- For screenshot/branding: Refer to `BRANDING_GUIDE.md`.
- For repository issues: Contact the DevOps lead.

Thank you for keeping our documentation professional and up-to-date!