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

## 8. Image Annotation Workflow

This section guides you through the entire process of annotating screenshots and diagrams for the Moove documentation. Following these steps ensures consistency, high quality, and smooth collaboration.

### 8.1 Understand the Issue

- **Read the GitHub issue carefully.**  
  It will specify:
  - The **exact file path** of the image to annotate (e.g., `UserGuide/screenshots/login_form.png`).
  - **Context** – which section of the document uses this image and what it should illustrate.
  - **Annotation requirements** – callouts, arrows, highlights, and the brand colors to use.
  - **Redaction needs** – any sensitive data (emails, passwords, real names) must be blurred.
  - **Additional files** – you must also include the **original unannotated source** in your PR.

- **Review the PDF context**  
  Before you start, open the final PDF of the relevant document (e.g., `UserGuide/UserGuide_Moove_Fleet.pdf`) and find the figure. This shows you exactly how the image is placed and what the surrounding text explains – your annotations should match that narrative.

### 8.2 Prepare Your Environment

- **Tools** – Use the recommended tools from the *Tools* table (Figma for annotations, PlantUML for diagrams, GIMP/Photoshop for complex edits).
- **Clone the repository** and ensure you have the latest `main` branch.
- **Install the required fonts** (if any) – check `BRANDING_GUIDE.md` for Moove‑specific typography.

### 8.3 Create a Dedicated Branch

**Rule: one annotation image per branch and per PR.**  
If you have two separate issues (e.g., annotate `login_form.png` and `dashboard_markers.png`), create **two separate branches** and **two separate PRs**.

- **Branch naming** – use a descriptive, issue‑aware name:
  ```
  feature/annotate-<image-filename>
  ```
  Examples:
  - `feature/annotate-login-form`  
  - `feature/annotate-dashboard-markers`

- **Create the branch** from the latest `main`:
  ```bash
  git checkout main
  git pull origin main
  git checkout -b feature/annotate-login-form
  ```

### 8.4 Locate and Copy the Source Image

- The image to annotate is inside the relevant document folder (e.g., `UserGuide/screenshots/`).
- **Make a copy** of the original image and place it in the **same folder** with a clear name (e.g., `login_form_source.png`).  
  This ensures the repository always retains a clean source for future updates.

### 8.5 Perform the Annotation

1. **Open the image** in your chosen editor (Figma, GIMP, Photoshop, etc.).
2. **Apply redactions** first – blur or black‑out any personally identifiable information (PII) like email addresses, names, or phone numbers.
3. **Add annotations** as required:
   - **Numbered callouts** – use circles with numbers, using **Moove Blue (`#0057B8`)** for the background.
   - **Arrows and highlights** – use **Green (`#2E8B57`)** for arrows and highlight boxes.
   - Keep annotations clean and consistent with the style defined in `BRANDING_GUIDE.md`.
4. **Export** the annotated image:
   - Format: **PNG**.
   - Resolution: **1920×1080** or higher (retain sharpness for PDF).
   - Compression level: **6–8** to keep file size under **2 MB**.
5. **Save the annotated file** with the **original filename** (overwriting the existing one) – this is required because the LaTeX document references that exact path.

### 8.6 If the Image Is Generated from Source (PlantUML, etc.)

- Many diagrams come from `.puml` files in the `plantuml/` folder.
- **Do not edit the PNG directly** – modify the `.puml` file, then regenerate the PNG using the PlantUML tool.
- Include both the updated `.puml` and the regenerated `.png` in your commit.
- Keep the source files under version control – this makes future updates easy and avoids rework.

### 8.7 Commit Your Changes

Write a clear, concise commit message that follows the project convention:

```
[Screenshots] Annotate login_form.png with step indicators

- Added numbered callouts for Email, Password, Login button, etc.
- Blurred test user email and password dots.
- Included original source as login_form_source.png.
```

**Important:**  
- One commit per annotation (if you have multiple images in the same branch, which is discouraged, use separate commits).
- The commit message **must reference the issue number** (e.g., `Closes #10` or `Refs #10`).

### 8.8 Open a Pull Request (PR)

- **One PR per image annotation** – do not combine multiple unrelated images in one PR.
- **Push your branch**:
  ```bash
  git push -u origin feature/annotate-login-form
  ```
- **Open the PR** against `main` and fill out the template:
  - **Summary** – what you changed and why.
  - **Linked issues** – mention the issue number (e.g., `Closes #10`).
  - **Checklist** – confirm that you followed the quality checklist (see section 5).
  - **Screenshots** – attach the **before** (source) and **after** (annotated) images for quick visual review.
- **Request a reviewer** (at least one).

### 8.9 Address Feedback and Merge

- Respond to all review comments.
- Make any required adjustments (amend your commit and force‑push if necessary, or add a new commit).
- Once approved, **use “Squash and Merge”** to keep the history clean.

### 8.10 Best Practices for Collaboration & Preventing Rework

- **Communicate early** – assign yourself to the issue and post a comment to let others know you’re working on it.
- **Use draft PRs** – open a draft PR as soon as you have a first version to get early feedback and avoid going too far off-track.
- **Keep your branch short‑lived** – merge within a day or two to minimise conflicts.
- **For AI‑generated content** (e.g., if you use an AI tool to create annotations or diagrams):
  - **Save the generation prompt/script** in a comment or a separate file (e.g., `generation_notes.txt`).
  - **Keep all source files** (the original image, the prompt, the editable layers) in the repository.
  - **Document the steps** to reproduce the image – this allows anyone to update it when the UI changes.
  - **Treat AI output like any other asset** – verify it against the brand guidelines and the PDF context before committing.
- **Reuse assets** – if a callout style or arrow is already used elsewhere, copy it from another annotated image to ensure consistency.
- **Review the `BRANDING_GUIDE.md`** frequently – it contains the definitive colour codes, font styles, and layout rules.


Thank you for keeping our documentation professional and up-to-date!