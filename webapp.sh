#!/bin/bash

# Generic script to initialize a Next.js + HeroUI frontend, Express + Prisma + Postgres backend project with Docker Compose
# Usage: bash generic_init.sh <project_name>
# Prerequisites: Node.js v20+, pnpm (npm i -g pnpm), Docker & Docker Compose
# After running: cd <project_name>, cp .env.example .env and fill it, docker-compose up --build

if [ $# -ne 1 ]; then
  echo "Usage: $0 <project_name>"
  exit 1
fi

PROJECT_NAME=$1

mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Create backend directory
mkdir backend
cd backend
pnpm init -y
pnpm add express @types/express typescript ts-node nodemon prisma @prisma/client dotenv node-cron
pnpm add -D @types/node concurrently

# Backend package.json
cat << EOF > package.json
{
  "name": "${PROJECT_NAME}-backend",
  "version": "1.0.0",
  "main": "dist/app.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/app.js",
    "dev": "nodemon --exec ts-node src/app.ts",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate dev"
  },
  "dependencies": {
    "@prisma/client": "^5.16.1",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "node-cron": "^3.0.3",
    "prisma": "^5.16.1"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/node": "^22.0.1",
    "concurrently": "^8.2.2",
    "nodemon": "^3.1.4",
    "ts-node": "^10.9.2",
    "typescript": "^5.5.4"
  }
}
EOF

# Backend tsconfig.json
cat << EOF > tsconfig.json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "outDir": "./dist",
    "rootDir": "./src"
  }
}
EOF

# Setup Prisma
npx prisma init --datasource-provider postgresql
cat << EOF > prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

// Add your models here
model Example {
  id        Int      @id @default(autoincrement())
  name      String
  createdAt DateTime @default(now())
}
EOF

# Backend src/app.ts
mkdir -p src
cat << EOF > src/app.ts
import express from 'express';
import path from 'path';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';
import cron from 'node-cron';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;
const prisma = new PrismaClient();

app.use(express.json());
app.use(express.static(path.join(__dirname, '../../frontend/.next'))); // Serve Next.js build

// Example API endpoint
app.get('/api/examples', async (req, res) => {
  const examples = await prisma.example.findMany();
  res.json(examples);
});

// Start server
app.listen(port, () => {
  console.log(\`Server running on port \${port}\`);
});

// Example cron job
cron.schedule('*/10 * * * *', () => {
  console.log('Running cron job');
});
EOF

# Backend Dockerfile
cat << EOF > Dockerfile
FROM node:20

WORKDIR /app

COPY package*.json ./
RUN pnpm install

COPY . .

RUN npx prisma generate
RUN npm run build

CMD ["node", "dist/app.js"]
EOF

cd ..

# Create frontend directory with Next.js
npx create-next-app@latest frontend --typescript --eslint --app --src-dir --import-alias "@/*" --use-pnpm
cd frontend
pnpm add @hero-ui/react @hero-ui/theme tailwindcss postcss autoprefixer
pnpm add -D @types/node

# Initialize Tailwind for HeroUI
npx tailwindcss init -p

# Update tailwind.config.js
cat << EOF > tailwind.config.js
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
    './node_modules/@hero-ui/**/*.js', // Add HeroUI content
  ],
  theme: {
    extend: {},
  },
  plugins: [],
  darkMode: 'class',
}
EOF

# Update src/app/globals.css
cat << EOF > src/app/globals.css
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

# Example page with HeroUI
cat << EOF > src/app/page.tsx
import { Button } from '@hero-ui/react';

export default function Home() {
  return (
    <div className="p-4">
      <h1>Welcome to ${PROJECT_NAME}</h1>
      <Button variant="solid">Click me</Button>
    </div>
  );
}
EOF

# Add HeroUI provider if needed (check docs, but for basic, this is fine)

cd ..

# Create docker-compose.yml
cat << EOF > docker-compose.yml
version: '3.8'

services:
  db:
    image: postgres:16
    restart: always
    environment:
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_DB: \${POSTGRES_DB}
    volumes:
      - db-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  backend:
    build: ./backend
    depends_on:
      - db
    environment:
      DATABASE_URL: "postgresql://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@db:5432/\${POSTGRES_DB}?schema=public"
      PORT: 3000
    ports:
      - "3000:3000"
    command: ["npm", "run", "start"]

volumes:
  db-data:
EOF

# .env.example
cat << EOF > .env.example
POSTGRES_USER=user
POSTGRES_PASSWORD=password
POSTGRES_DB=${PROJECT_NAME}_db
EOF

# Git init
git init
git add .
git commit -m "Initial generic project setup with Next.js + HeroUI, Express + Prisma + Postgres"

echo "Generic project '$PROJECT_NAME' created! cd $PROJECT_NAME, cp .env.example .env and fill it, docker-compose up --build"
echo "For dev: cd backend, npm run dev; cd frontend, pnpm dev"
echo "Build frontend: cd frontend, pnpm build; then serve via backend."
