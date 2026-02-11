# Finly - Financial Intelligence System

**Finly** is a robust, enterprise-grade personal and business finance management application. Built with **Flutter** and **Dart**, the project is designed to demonstrate high-level architectural patterns, scalability, and strict adherence to software engineering best practices.

---

## 👨‍💻 Developer Information
* **Name:** Ottavio Lucri de Souza
* **Education:** Student at Federal University of Itajubá (UNIFEI)
* **Focus:** Mobile Development & Software Architecture

---

## 🏛 Architecture & Principles

The project is built using **Clean Architecture**, ensuring a complete separation of concerns and high testability. The code is divided into three primary layers:

1.  **Domain Layer:** The "heart" of the application, containing purely Dart code (Entities, Use Cases, and Repository Interfaces). It has zero dependencies on external frameworks.
2.  **Data Layer:** Responsible for data persistence and external integrations (Supabase, OCR APIs, Local Storage).
3.  **Presentation Layer:** Handles UI state management (BLoC/Provider) and user interactions.

### Key Engineering Principles:
* **SOLID:** Strict adherence to all five principles, particularly the **Dependency Inversion Principle (DIP)**.
* **Functional Error Handling:** Utilizing the `dartz` package for `Either<Failure, Success>` patterns, avoiding excessive try-catch blocks.
* **Offline-First:** Designed with **UUIDs** to ensure data integrity during synchronization without internet connectivity.

---

## 🚀 Key Features

### 🏢 Dual-Workspace Environment
Unlike standard trackers, Finly allows users to toggle between **Personal (CPF)** and **Business (CNPJ)** workspaces within a single login, maintaining complete data isolation.

### 📊 Financial Intelligence
* **12-Month Forecasting:** Predictive cash-flow analysis based on scheduled transactions and historical data.
* **Investment Yield Simulator:** Real-time growth calculations for assets (e.g., CDI/Fixed Income).
* **Credit Card Engine:** Deep tracking of statements, limits, and due dates.

### 🛡 Robustness & Security
* **Audit Logging:** Read-only records of every financial modification for data integrity.
* **Biometric Authentication:** Secure access via FaceID/Fingerprint.
* **Receipt OCR:** Automated expense entry using Optical Character Recognition.

---

## 🛠 Tech Stack
* **Frontend:** Flutter & Dart
* **Backend:** Supabase (PostgreSQL, Auth, Storage)
* **State Management:** BLoC / Provider
* **Local DB:** Drift (SQLite) / Hive
* **Packages:** Equatable, Dartz, Google ML Kit

---

## 📅 Project Roadmap
- [x] **Sprint 1:** Domain Layer setup (Entities & Use Cases)
- [ ] **Sprint 2:** Data Layer integration (Supabase Auth & Database)
- [ ] **Sprint 3:** Core Features (Transaction Flow & Credit Cards)
- [ ] **Sprint 4:** Advanced Intelligence (OCR & Forecasting)

---