# E-Banking Platform

Java 17 / Spring Boot banking platform with service-owned H2 data stores, API Gateway, Eureka discovery, KYC authentication, and a React client.

- [System architecture and repository layout](docs/phase-1/architecture.md)
- [Backend API test criteria and observed results](test%20criteria.txt)
- [Live API smoke runner](tests/backend-api-smoke.ps1)

## Run locally

Install a JDK (17 or later) and Node.js 22 or later. Java, `javac`, Node.js, and npm must be on `PATH`. Gradle is downloaded by the included wrapper; no database server or Docker installation is needed. Internet access is needed for the first dependency download.

On Windows, double-click [run-all.bat](run-all.bat), or run `run-all.bat --check` for a non-interactive startup. The launcher builds the Java services with Gradle, installs frontend packages with `npm ci` if needed, starts the services as local Java processes, and opens `http://127.0.0.1:5173/`. The frontend uses Vite and proxies API requests to the gateway on port 8080.

Use [stop-all.bat](stop-all.bat) or `run-all.bat -Stop` to stop the processes. Logs and process IDs are stored in the ignored `.run/` directory. Each database-backed service uses its own file-backed H2 database in the ignored `data/` directory; stopping the app preserves this data. Back up that directory before deleting it.

If startup fails, inspect `.run/<service>.err.log` and `.run/<service>.out.log`. Ports 5173, 8080, 8081–8086, and 8761 must be free. A previously running Docker stack or development server can occupy these ports.

On macOS/Linux, run `./gradlew bootJar` from the repository root, then start the discovery server, six services, and gateway with `java -jar <module>/build/libs/<module>-1.0.0-SNAPSHOT.jar`. Start discovery first. In [web/](web/), run `npm ci` and `npm run dev`. The application defaults to local H2 databases and `http://localhost:8761/eureka` for discovery.

Existing MySQL data is not migrated to H2. The H2 schema is generated from JPA mappings for local development and is not a production database. Set `JWT_SECRET` to a high-entropy value outside local development.

Run the API smoke subset with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/backend-api-smoke.ps1 -SmokeOnly`. The full acceptance run intentionally exits nonzero: financial transfer posting, enrolled MFA, and durable fraud alerts are not implemented yet. Transfer requests fail closed with HTTP 503.
