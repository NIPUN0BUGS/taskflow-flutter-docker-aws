# TaskFlow — Flutter + Dart + Docker + AWS Interview Project

TaskFlow is a small task-management app designed to practise UI/UX thinking, Flutter/Dart, REST APIs, Docker/containerization, and AWS deployment.

## Stack

- **Frontend:** Flutter + Dart (Flutter Web)
- **Backend:** Node.js + Express REST API
- **Database:** PostgreSQL
- **Local containers:** Docker + Docker Compose
- **AWS target architecture:** ECR + ECS Fargate + Application Load Balancer + RDS PostgreSQL; Flutter Web hosted on private S3 behind CloudFront

## Repository layout

```text
backend/                  Express API and Dockerfile
  src/app.js              REST routes and validation
  src/db.js               PostgreSQL pool and schema initialization
  src/server.js           API server startup
  .env.example            Local environment variable template
  Dockerfile              API container image
flutter_app/              Flutter/Dart application source
  lib/main.dart           App theme and entry point
  lib/models/task.dart    Task model
  lib/screens/home_screen.dart
  lib/services/task_service.dart
  pubspec.yaml
docker-compose.yml        Local API + PostgreSQL services
README.md
```

## Requirements

- Flutter SDK and Chrome (web target enabled)
- Docker Desktop with Docker Compose
- Node.js 22+ (optional for running the API directly)
- AWS CLI and an AWS account only for the optional cloud deployment

## Run locally

From the repository root:

```bash
docker compose up --build
```

Check API health and task endpoints:

```bash
curl http://localhost:3000/health
curl http://localhost:3000/api/tasks
```

Create a task:

```bash
curl -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Prepare for interview","description":"Practise Flutter and Docker"}'
```

In a second terminal, generate Flutter web scaffolding once and run the app:

```bash
cd flutter_app
flutter create . --platforms web
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

For Android Emulator, use `--dart-define=API_BASE_URL=http://10.0.2.2:3000`.

## API endpoints

| Method | Endpoint | Purpose |
| --- | --- | --- |
| GET | `/health` | API/database health check |
| GET | `/api/tasks` | List tasks |
| POST | `/api/tasks` | Create a task |
| PATCH | `/api/tasks/:id` | Update task fields |
| DELETE | `/api/tasks/:id` | Delete a task |

## Docker concepts to practise

```bash
docker ps
docker compose logs -f api
docker build -t taskflow-api ./backend
docker compose down
```

Be ready to explain images vs containers, Dockerfiles, Compose, port mapping, environment variables, volumes, and why database data should persist beyond the lifetime of a container.

## AWS deployment learning path

1. Build the API Docker image and push it to **Amazon ECR**.
2. Run the image as an **ECS Fargate** service behind an **Application Load Balancer**.
3. Use **Amazon RDS for PostgreSQL** for persistent production data, with the database in private subnets and access restricted to the API security group.
4. Build Flutter Web with the public API URL and upload `build/web/` to a private **S3** bucket.
5. Serve the static frontend using **CloudFront** and HTTPS.
6. Store production secrets in **AWS Secrets Manager** or **SSM Parameter Store**; never commit real credentials.

Set a budget alert before creating cloud resources. AWS can charge for deployed services; delete practice infrastructure when finished. Verify current AWS service pricing and documentation before deployment.

## Interview practice

### UI/UX
- Who is the target user and what problem does TaskFlow solve?
- How are visual hierarchy, spacing, contrast, validation, loading/error states and accessibility handled?
- How would you test usability?

### Dart and Flutter
- What is the difference between `StatelessWidget` and `StatefulWidget`?
- What are `Future`, `async` and `await`?
- How do JSON responses become typed Dart models?
- When might you choose Provider or Riverpod instead of `setState`?

### API and database
- Explain GET, POST, PATCH and DELETE.
- Why validate request bodies and use parameterized SQL?
- How should database errors and secrets be handled?

### Docker and AWS
- What is the difference between an image and a container?
- What do Docker Compose, volumes and port mappings do?
- What are the roles of ECR, ECS, Fargate, ALB, RDS, S3 and CloudFront?
- How would you debug a failed health check or HTTP 502?

## Recommended order

1. Start API/database with Compose; test CRUD using curl.
2. Explore the Flutter widget tree and UI.
3. Connect the Flutter client to the API.
4. Practise Docker commands and explain each configuration file.
5. Deploy only after local tests pass and a cloud budget is set.

> **Testing note:** This is a learning starter. Run the commands locally and fix any environment-specific issues before describing it as production-ready or fully tested.
