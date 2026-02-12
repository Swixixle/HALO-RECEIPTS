# HALO-RECEIPTS

AI Receipts - Forensic Verification System for AI Conversation Transcripts

[![Run on Replit](https://replit.com/badge/github/Swixixle/HALO-RECEIPTS)](https://replit.com/github/Swixixle/HALO-RECEIPTS)

## Overview

AI Receipts is a forensic verification system for AI conversation transcripts. It provides cryptographic verification of receipt capsules, immutable storage, and forensic analysis capabilities.

For detailed documentation, see [replit.md](./replit.md)

## Quick Start

### Replit Quickstart (Operator Demo)

**For non-technical evaluators**: Run this app in Replit in under 5 minutes.

1. **Import from GitHub**
   - Click the "Run on Replit" badge above, or
   - In [Replit](https://replit.com), click "Create Repl" → "Import from GitHub"
   - Paste this repository URL

2. **Install Dependencies**
   ```bash
   npm ci
   ```
   - If `npm ci` fails due to lockfile mismatch (e.g., missing `bufferutil`):
     - Run `npm install` instead
     - Commit the updated `package-lock.json` in a small PR

3. **Set up PostgreSQL Database**
   - Click "Tools" sidebar in Replit
   - Add "PostgreSQL" database
   - The `DATABASE_URL` will be automatically added to your Secrets

4. **Initialize Database Schema**
   ```bash
   npm run db:push
   ```

5. **Run the Development Server**
   ```bash
   npm run dev
   ```
   - Server listens on port 5000 (http://localhost:5000)
   - Replit webview will auto-open

**How to Use:**
- **Start Here**: Guided workflow for new users
- **Use Cases**: Industry menu + pattern library
- **Browse Receipts**: Open any receipt, then follow the workflow chips:
  - Verify → Inspect → Export
  - Use the collapsible advanced actions for deeper operations

**Troubleshooting:**

Port 5000 already in use (EADDRINUSE):
```bash
pkill -f "tsx server/index.ts" || true
pkill -f "server/index.ts" || true
pkill -f "vite" || true
npm run dev
```

Clean reinstall:
```bash
rm -rf node_modules && npm ci
```

Note: You may see an `EBADENGINE` warning depending on Replit's Node version. This is informational only; the app will still run.

**Notes for Contributors (Replit ↔ GitHub):**
- Replit paste artifacts (`attached_assets/Pasted-*.txt`) are ignored via `.gitignore`
- GitHub blocks OAuth apps from modifying `.github/workflows/*` without `workflow` scope
  - Either don't edit workflows from Replit OAuth, or
  - Use a personal access token with `workflow` scope, or
  - Edit workflows directly in GitHub

For more details, see [docs/REPLIT_SETUP.md](./docs/REPLIT_SETUP.md)

### Local Development

1. **Prerequisites**
   - Node.js 20+
   - PostgreSQL database
   - npm or yarn

2. **Installation**
   ```bash
   npm install
   ```

3. **Configuration**
   - Copy `.env.example` to `.env`
   - Update `DATABASE_URL` with your PostgreSQL connection string
   - Set other environment variables as needed

4. **Database Setup**
   ```bash
   npm run db:push
   ```

5. **Run Development Server**
   ```bash
   npm run dev
   ```

The application will start on port 5000 (http://localhost:5000)

## Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run start` - Start production server
- `npm run check` - Type check with TypeScript
- `npm run db:push` - Push database schema changes

## Technology Stack

- **Frontend**: React + TypeScript + Tailwind CSS + shadcn/ui
- **Backend**: Express.js + Node.js 20
- **Database**: PostgreSQL with Drizzle ORM
- **Validation**: Zod schemas
- **Cryptography**: Node.js crypto (SHA-256)

## Documentation

- [Full Documentation](./replit.md) - Complete API and feature documentation
- [Replit Setup Guide](./docs/REPLIT_SETUP.md) - Step-by-step Replit deployment
- [Receipt Capsule v2 Proposal](./docs/RECEIPT_CAPSULE_V2.md) - Future schema evolution

## Core Features

- **Receipt Verification**: Validates AI conversation receipts using SHA-256 hash verification
- **Canonicalization (c14n-v1)**: Deterministic JSON canonicalization for consistent hashing
- **Immutable Storage**: Verified receipts are locked and cannot be modified
- **Kill Switch**: Irreversible control to permanently disable interpretation for a receipt
- **Interpretation System**: Categorized as FACT, INTERPRETATION, or UNCERTAINTY (append-only)
- **Tri-Sensor Analysis**: Parallel analysis with interpreter, summarizer, and claim extractor

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT

---

### User Information
- **Current User's Login:** Swixixle
