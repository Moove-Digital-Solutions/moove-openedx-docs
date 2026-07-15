# Moove Education Platform Documentation

This repository contains the complete documentation suite for the **Moove Education Platform** – an Open edX-based learning management system deployed using Tutor. The documentation is designed to serve both as a reference for internal development and as a submission package for government security assessment and compliance certification.

The suite comprises five core documents:

- **SRS (Software Requirements Specification)** – Defines functional and non‑functional requirements.
- **SDD (System & Architecture Design)** – Describes the system’s physical and logical architecture with UML diagrams.
- **TDD (Technical Design Document)** – Provides API specifications, database schemas, and design traceability.
- **User Guide** – Step‑by‑step instructions for learners, instructors, and administrators.
- **Security Assessment** – Architecture overview, threat model, security findings, and hardening guide.

All documents are written in **LaTeX** and share common components (preamble, cover page, footer, license) to ensure consistency and maintainability.

---

## 📁 Project Structure

```
moove-openedx-docs/
├── README.md
├── build.sh
├── logo.png
├── common/
│   ├── preamble.tex
│   ├── cover.tex
│   ├── footer.tex
│   └── license.tex
├── SRS/
│   └── SRS_OpenEdX.tex
├── SDD/
│   ├── SDD_OpenEdX.tex
│   └── diagrams/
│       ├── usecase.png
│       ├── class.png
│       └── sequence_enrollment.png
├── TDD/
│   ├── TDD_OpenEdX.tex
│   └── diagrams/
│       ├── er.png
│       └── activity_course_publish.png
├── UserGuide/
│   ├── UserGuide_OpenEdX.tex
│   └── screenshots/
│       ├── login.png
│       ├── dashboard.png
│       ├── course_authoring.png
│       └── ... (other screenshots)
├── Security/
│   └── Security_OpenEdX.tex
└── plantuml/
    ├── usecase.puml
    ├── class.puml
    ├── sequence_enrollment.puml
    ├── er.puml
    └── activity_course_publish.puml
```

---

## 🛠️ Prerequisites

- **TeX Live** or **MacTeX** (for `pdflatex`)
- **PlantUML** (optional, for generating diagram images)
- **ImageMagick** (if you need to convert images)

On Debian/Ubuntu, install the required packages:

```bash
sudo apt install texlive-latex-extra texlive-fonts-recommended texlive-fonts-extra
```

For PlantUML, you can use the command-line tool or the online PlantUML server.  
Alternatively, you can use a local Java installation:

```bash
sudo apt install plantuml
```

---

## 📦 Compilation Instructions

1. **Clone or download** this repository.
2. **Place your logo** as `logo.png` in the root directory.
3. **Generate diagram images** (if not already present):
   ```bash
   cd plantuml
   plantuml -tpng *.puml
   mv usecase.png class.png sequence_enrollment.png ../SDD/diagrams/
   mv er.png activity_course_publish.png ../TDD/diagrams/
   ```
4. **Add screenshots** to `UserGuide/screenshots/` (replace placeholders with actual images).
5. **Run the build script**:
   ```bash
   chmod +x build.sh
   ./build.sh
   ```

The script runs `pdflatex` twice for each document to resolve cross‑references.  
Output PDFs will be saved in each document’s respective folder.

---

## 📄 Document Overview

### 1. Software Requirements Specification (SRS)
- **File:** `SRS/SRS_OpenEdX.tex`
- **Purpose:** Defines all functional and non‑functional requirements grouped by module (User Management, Course Management, Enrollment, Assessments, Discussions, Analytics, Administration).
- **Traceability:** Includes a traceability matrix linking requirements to test cases.

### 2. System & Architecture Design (SDD)
- **File:** `SDD/SDD_OpenEdX.tex`
- **Purpose:** Describes the physical and logical architecture, including container services, data storage, and UML diagrams.
- **Diagrams:** Use Case, Class, and Sequence (Enrollment).

### 3. Technical Design Document (TDD)
- **File:** `TDD/TDD_OpenEdX.tex`
- **Purpose:** Details API endpoints, database schemas, and design traceability.
- **Diagrams:** Entity‑Relationship (ER) and Activity (Course Publishing).

### 4. User Guide
- **File:** `UserGuide/UserGuide_OpenEdX.tex`
- **Purpose:** Step‑by‑step instructions for learners, instructors, and administrators.
- **Screenshots:** Place your actual screenshots in `UserGuide/screenshots/` and reference them by filename.

### 5. Security Assessment
- **File:** `Security/Security_OpenEdX.tex`
- **Purpose:** Identifies threats, evaluates current controls, and provides a hardening plan based on a live deployment audit.

---

## 🔧 Customisation Tips

- **Change the platform name:** Update the `\def\docTitle` and `\fancyhead` sections in each `.tex` file.
- **Add more screenshots:** Add new `\includegraphics` entries in the User Guide and place the images in `screenshots/`.
- **Modify the traceability matrix:** Update the tables in the SRS and TDD to match your actual requirements.
- **Adjust the color scheme:** Change the `\definecolor{mooveblue}` in `common/preamble.tex`.

---

## 📋 License

This documentation itself is licensed under the **Apache License 2.0** to be compatible with the software it documents (Open edX and Traccar). See the `common/license.tex` file for the full text.

---

## 🤝 Contributing

1. Fork the repository.
2. Make your changes.
3. Test compilation with `./build.sh`.
4. Submit a pull request with a clear description of your changes.

---

## 📧 Contact

For questions or support regarding this documentation suite, contact the Moove Education Engineering Team at [your-email@example.com].

---
