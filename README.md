# 🧠 KIOKU — Context-Aware AI Browser for Deep Learning

KIOKU is a **Flutter-based AI-powered mobile browser** designed to eliminate **context loss** while learning, researching, or analyzing information on the web.

Whether you are a student navigating complex topics across dozens of sources or a professional tracking evolving information, the core problem remains the same:

> **Fragmented knowledge.**

KIOKU transforms scattered web pages into a **project-centric, contextual knowledge base** that understands meaning, not just keywords.

---

## 🚀 What is KIOKU?

KIOKU is an in-app mobile browser that allows users to:

- Browse real websites
- Save pages into **Projects**
- Convert saved content into **semantic embeddings**
- Interact with the project using AI-powered tools

The result is a browser that **remembers what you’ve read** and uses that memory to help you think, learn, and decide better.

---
## 🧠 Why “KIOKU”?

**Kioku (記憶)** is a Japanese word that means **“memory.”**

The name reflects the core idea behind KIOKU:
not just browsing information, but **remembering it with context**.

Unlike traditional browsers that forget everything once a tab is closed,  
KIOKU builds a **persistent, project-based memory** of what you read, learn, and analyze.

Your research doesn’t disappear.  
It accumulates, connects, and stays with you.

## 🧩 Core Concept: Projects

A **Project** represents a focused topic or goal (e.g., *Python*, *Stock Market*, *Research Paper*).

- Each project can contain **multiple web pages**
- All pages under a project share a **common semantic context**
- AI interactions operate over the **entire project**, not a single page

---

## ⚡ KIOKU Edge

Once a project is created, users can interact with it in **three powerful ways**:

### 1️⃣ Chat with Project
Ask questions like:
- “Explain this concept simply”
- “Summarize everything I saved”
- “Compare viewpoints across sources”

The AI responds using **full project context**, not isolated snippets.

### 2️⃣ MCQ Generator
KIOKU generates **project-specific quizzes** to help users:
- Test understanding
- Reinforce memory
- Learn actively instead of passively reading

### 3️⃣ Project Management
- Add new pages to existing projects
- Revisit saved knowledge anytime
- Build a growing personal knowledge base

---

## 🏗️ Architecture Overview

### High-Level Flow

1. User browses a webpage inside the KIOKU app
2. Page is saved to a selected Project
3. Page content is:
   - Extracted
   - Embedded into vectors
   - Stored in the database with Project ID
4. Embeddings are processed using **Gemini AI**
5. Results are returned in structured form and displayed in the app

### Data Model (Simplified)

- **Project**
  - project_id
  - user_id
  - metadata

- **Pages**
  - url
  - project_id
  - embeddings
  - extracted content

Multiple pages → one project → shared context.

---
## 🎥 Demo Video

Watch a short demo of KIOKU in action:

▶️ https://youtube.com/shorts/KiZXbqFWl3o?si=WGHhAThWgtSgw84v

## 🛠️ Tech Stack

- **Frontend:** Flutter (Dart)
- **Platform:** Android (mobile-first)
- **Backend / Storage:** Firebase / Supabase
- **Vector Storage:** Embeddings stored per page
- **AI Model:** Google Gemini
- **Auth:** User-based authentication
- **Architecture:** Project-centric semantic retrieval

---

## ✅ Current Status

**Status:** Functional MVP

- Core features implemented and working
- AI summarization, chat, and MCQ generation live
- Actively evolving with ongoing improvements

---

## 🛣️ Roadmap

- Improve contextual merging across domains
- Optimize embedding retrieval performance
- Enhance UI/UX for long research sessions
- Cross-project semantic linking
- Browser extension companion (future)

---

## 🎯 Why KIOKU?

Most tools help you **search**.

KIOKU helps you **remember, connect, and understand**.

It is not just a browser.
It is a **personal contextual knowledge system**.

---

## 👤 Author

**Armaan Sharma**  
GitHub: https://github.com/13armaan

---

## 📄 License

MIT License

