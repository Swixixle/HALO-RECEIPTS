# Replit Setup Guide

This guide will help you set up and run the HALO-RECEIPTS application on Replit.

## Replit Quickstart (Operator Demo)

**For non-technical evaluators**: Run this app in Replit in under 5 minutes.

### 1. Import from GitHub

- Go to [Replit](https://replit.com)
- Click "Create Repl" → "Import from GitHub"
- Paste this repository URL: `https://github.com/Swixixle/HALO-RECEIPTS`

### 2. Install Dependencies

Open the Shell in Replit and run:

```bash
npm ci
```

**If `npm ci` fails** due to lockfile mismatch (e.g., missing `bufferutil`):
- Run `npm install` instead
- Commit the updated `package-lock.json` in a small PR
- This ensures future runs use `npm ci` cleanly

### 3. Set up PostgreSQL Database

- Click the "Tools" sidebar in Replit
- Add "PostgreSQL" database
- The `DATABASE_URL` will be automatically added to your Secrets
- No manual configuration needed

### 4. Configure Environment Variables (Optional)

Go to the "Secrets" tab (lock icon in sidebar). The following are auto-configured or have defaults:

- `DATABASE_URL` - (auto-populated by PostgreSQL tool)
- `NODE_ENV` - Set to `development` (default)
- `PORT` - Port number (default: `5000`)

Optional variables:
- `API_KEY` - Your API key (or use `dev-test-key-12345` for development)
- `SESSION_SECRET` - A random string for session security
- `TRANSCRIPT_MODE` - Display mode: `full`, `redacted`, or `hidden` (default: `full`)

### 5. Initialize the Database

```bash
npm run db:push
```

This creates the database schema required by the application.

### 6. Run the Development Server

```bash
npm run dev
```

- Server listens on **port 5000** (http://localhost:5000)
- Replit webview will auto-open to the app
- The landing page is **Start Here**, which guides you through the operator workflow

## How to Use the Operator-First UI

### Start Here (Landing Flow)

The **Start Here** page is your guided entry point:
- Introduction to cryptographic verification
- Walkthrough of core features
- Links to Use Cases and Browse Receipts

### Use Cases (Industry Menu)

Navigate to **Use Cases** to explore:
- **Compliance & Audit**: Regulatory record-keeping
- **Customer Support**: Verified conversation logs
- **Legal & Regulatory**: Chain-of-custody for evidence

Each use case explains how verification applies to that domain.

### Browse Receipts (Workflow Chips)

1. Click **Browse Receipts** in the navigation
2. Open any receipt from the list
3. Follow the **workflow chips** at the top:
   - **Verify** → Cryptographic hash check (SHA-256)
   - **Inspect** → View receipt details and interpretations
   - **Export** → Download forensic pack
4. Use the **collapsible advanced actions** for:
   - Kill Switch (irreversible interpretation disable)
   - Chain Analysis
   - Signature Details

## Troubleshooting

### Port 5000 Already in Use (EADDRINUSE)

If you see "Port 5000 is already in use", terminate any existing processes:

```bash
pkill -f "tsx server/index.ts" || true
pkill -f "server/index.ts" || true
pkill -f "vite" || true
npm run dev
```

**Note**: The `|| true` ensures the command continues even if no matching process is found.

### Clean Reinstall

If you encounter dependency or build errors:

```bash
rm -rf node_modules && npm ci
```

### EBADENGINE Warning

You may see a warning like:

```
WARN EBADENGINE Unsupported engine
```

This is informational only and depends on Replit's Node version. **Do not change the code**; the app will still run correctly.

### Database Connection Issues

1. Ensure PostgreSQL is added from the Tools sidebar
2. Check that `DATABASE_URL` is in your Secrets
3. Try running `npm run db:push` to initialize the schema

## Notes for Contributors (Replit ↔ GitHub)

### Replit Paste Artifacts

Files like `attached_assets/Pasted-*.txt` are automatically created by Replit when you paste content. These are ignored via `.gitignore` and will not be committed.

### Editing GitHub Workflows from Replit

GitHub blocks OAuth apps from modifying `.github/workflows/*` without the `workflow` scope.

**Options**:
1. **Don't edit workflows from Replit** (recommended for most contributors)
2. Use a **personal access token with `workflow` scope** instead of OAuth
3. Edit workflows **directly in GitHub** using the web interface

This is a GitHub security policy to prevent unauthorized CI/CD modifications.

## Available Scripts

- `npm run dev` - Start development server (port 5000)
- `npm run build` - Build for production
- `npm run start` - Start production server
- `npm run check` - Type check with TypeScript
- `npm run db:push` - Push database schema changes

## Production Deployment

For production deployment on Replit:

1. Set `NODE_ENV=production` in Secrets
2. Set a secure `API_KEY`
3. Set a secure `SESSION_SECRET`
4. Run `npm run build` to create the production build
5. Use the deployment configuration in `.replit`

## Support

For more information:
- [DEMO_README.md](./DEMO_README.md) - 5-minute evaluator walkthrough
- [START_HERE.md](./START_HERE.md) - System overview and reading map
- [replit.md](../replit.md) - Full API and feature documentation
- [README.md](../README.md) - Main project documentation
