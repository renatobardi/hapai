# 02 Projects
FROM node:20-alpine AS builder

WORKDIR /app

# Copy root files
COPY package.json package-lock.json tsconfig.json .eslintrc.json .prettierrc ./
COPY packages/02_projects ./packages/02_projects
COPY shared ./shared

# Install dependencies
RUN npm install --legacy-peer-deps

# Build
WORKDIR /app/packages/02_projects
RUN npm run build

# Final stage
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./
COPY packages/02_projects/package.json ./packages/02_projects/
COPY shared ./shared

# Install production dependencies only
RUN npm ci --legacy-peer-deps --production && npm cache clean --force

# Copy built app
COPY --from=builder /app/packages/02_projects/build ./packages/02_projects/build

EXPOSE 3002

ENV NODE_ENV=production

CMD ["node", "packages/02_projects/build/index.js"]
