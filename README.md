# E-Banking Platform

Production-oriented Java 17 / Spring Boot banking platform with isolated service data stores, transactional ledger posting, API Gateway, discovery, KYC authentication, and a React client.

- [System architecture and repository layout](docs/phase-1/architecture.md)
- [MySQL DDL scripts](database/ddl/)
- [Local infrastructure Compose file](docker/docker-compose.yml)
- [Backend API test criteria and observed results](test%20criteria.txt)
- [Repeatable live API/DB smoke runner](tests/backend-api-smoke.ps1)

## Run locally

On Windows, double-click [run-all.bat](run-all.bat), or run `run-all.bat` from Command Prompt. It builds and starts the full Docker stack, starts the React development server if needed, waits for the gateway and UI, then opens `http://localhost:5173/` in the default browser. Keep the React server window open while using the app. The launcher pauses at completion or on error so its output remains visible. For a non-interactive startup check without opening a browser, run `run-all.bat --check`.

Alternatively:

1. Start the stack: `docker compose -f docker/docker-compose.yml up -d --build`.
2. In [web/](web/), run `npm install` then `npm run dev`.

Set `JWT_SECRET` to a high-entropy secret and use managed database, Kafka, Redis, key-management, and observability services outside local development.

The API/DB smoke subset can be rerun with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/backend-api-smoke.ps1 -SmokeOnly`. The full acceptance run intentionally exits nonzero: financial transfer posting, enrolled MFA, and durable fraud alerts are not implemented yet. Transfer requests fail closed with HTTP 503 and do not create ledger rows.
