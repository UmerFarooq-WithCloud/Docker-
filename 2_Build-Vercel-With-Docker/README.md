# 2_Build-Vercel-With-Docker

## Overview

This project demonstrates a Docker-based build pipeline that clones a Git repository, builds a Vite/React app, uploads generated assets to an S3 bucket, and then serves those assets through a reverse proxy using hostname-based routing.

The architecture includes:
- `api-server`: accepts build requests and launches AWS ECS tasks
- `build_server`: Docker image that clones the repository, runs the build, and uploads output to S3
- `s3-reverse-proxy`: proxies requests to S3 by hostname/subdomain
- `vite_practice_repo/practice-for-vercel`: sample Vite React app used for build tests

## Folder structure

- `api-server/`
  - `index.js` - Express API and socket log server
  - `package.json`
- `build_server/`
  - `Dockerfile` - builder container image
  - `bash.sh` - clone script
  - `script.js` - build script and S3 uploader
  - `package.json`
- `s3-reverse-proxy/`
  - `index.js` - reverse proxy to S3
- `vite_practice_repo/practice-for-vercel/`
  - Vite React sample application
- `project images/` and `infrastructure of project.png`
  - diagrams and screenshots

## Component details

### `api-server`

The API server exposes a POST route at `/project`:
- Accepts JSON with `gitURL` and optional `slug`
- Uses AWS ECS to run a Fargate task from a task definition
- Supplies `GIT_REPOSITORY__URL` and `PROJECT_ID` to the build container
- Uses Redis pub/sub and Socket.IO to stream build logs to clients

Required configuration values in `api-server/index.js`:
- AWS region
- AWS credentials (`accessKeyId`, `secretAccessKey`)
- ECS cluster name
- ECS task definition name
- Subnets and security groups for Fargate
- Redis connection string

### `build_server`

The builder Docker image does the following:
- Starts from `ubuntu:focal`
- Installs `curl`, Node.js 20, Git
- Copies `bash.sh`, `script.js`, and the package files
- Installs dependencies
- Runs `bash.sh` as the entrypoint

`bash.sh` clones the repository from `GIT_REPOSITORY__URL` into `/app/output`, then runs `node script.js`.

`script.js`:
- Reads `PROJECT_ID` from environment
- Runs `npm install && npm run build` inside `/app/output`
- Uploads files from `/app/output/dist` into S3 under `__outputs/${PROJECT_ID}/`
- Publishes build logs to Redis

Current hardcoded values:
- S3 bucket: `project-purpose-bucket-unique`
- S3 base path: `__outputs/${PROJECT_ID}`
- AWS region: `us-east-1`

### `s3-reverse-proxy`

The reverse proxy listens on port `8000` and routes requests based on hostname:
- Extracts the first subdomain from the request hostname
- Proxies all requests to the S3 path for that subdomain
- If the request URL is `/`, the proxy serves `index.html`

Configured base path:
- `https://vercel-clone-outputs.s3.ap-south-1.amazonaws.com/__outputs`

Example:
- `p1.localhost:8000` → S3 path `.../__outputs/p1`
- `a1.localhost:8000` → S3 path `.../__outputs/a1`

### Sample app: `vite_practice_repo/practice-for-vercel`

This folder contains a Vite + React sample project:
- `vite.config.js`
- `index.html`
- `package.json`

It can be built with:

```bash
cd vite_practice_repo/practice-for-vercel
npm install
npm run build
```

## Setup instructions

### 1. Prepare AWS and Redis

- Create or configure an S3 bucket for build output.
- Configure an AWS ECS cluster and task definition.
- Provide valid AWS credentials.
- Run a Redis instance reachable from both `api-server` and `build_server`.

### 2. Start the API server

```bash
cd 2_Build-Vercel-With-Docker/api-server
npm install
node index.js
```

### 3. Build and run the build container

From `2_Build-Vercel-With-Docker/build_server`:

```bash
docker build -t vite-build-server .
```

Run with environment variables:

```bash
docker run --rm \
  -e GIT_REPOSITORY__URL="<repo-url>" \
  -e PROJECT_ID="my-project-id" \
  -e AWS_ACCESS_KEY_ID="..." \
  -e AWS_SECRET_ACCESS_KEY="..." \
  -e REDIS_URL="..." \
  vite-build-server
```

Note: the current `script.js` expects Redis at `new Redis('')` and AWS credentials directly in the file. Replace placeholders with real values.

### 4. Start the reverse proxy

```bash
cd 2_Build-Vercel-With-Docker/s3-reverse-proxy
npm install express http-proxy
node index.js
```

### 5. Trigger a project build

Send a POST request to `http://localhost:9000/project` with JSON:

```json
{
  "gitURL": "https://github.com/your/repo.git"
}
```

The API responds with a `projectSlug` and a preview URL like:

```json
{ "status": "queued", "data": { "projectSlug": "abc-123", "url": "http://abc-123.localhost:8000" } }
```

### 6. View the deployed build

Open the URL from the response in your browser.

If you are testing locally, configure your hosts file or browser to resolve subdomains such as `abc-123.localhost` to `127.0.0.1`.

## Notes and limitations

- Many values are currently placeholders and must be updated before production.
- The build container assumes the cloned repo uses `npm run build` and outputs to `dist/`.
- The reverse proxy only supports static asset forwarding to S3 and adds `index.html` for root requests.
- The `api-server` socket log functionality is built with Socket.IO and Redis pub/sub.

## Recommended improvements

- Move AWS and Redis credentials to environment variables or a secure secrets manager.
- Add validation and error handling in `api-server` and `build_server`.
- Support custom S3 bucket names and regions through configuration.
- Add README files inside each subfolder to document local development steps.
