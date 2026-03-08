# 01 Auth-Profile
FROM node:20-alpine AS builder

WORKDIR /app

# Copy root files
COPY package.json package-lock.json tsconfig.json .eslintrc.json .prettierrc ./
COPY packages/01_auth-profile ./packages/01_auth-profile
COPY shared ./shared

# Install dependencies
RUN npm install --legacy-peer-deps

# Build
WORKDIR /app/packages/01_auth-profile
RUN npm run build

# Final stage
FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./
COPY packages/01_auth-profile/package.json ./packages/01_auth-profile/
COPY shared ./shared

# Install production dependencies only
RUN npm ci --legacy-peer-deps --production && npm cache clean --force

# Copy built app
COPY --from=builder /app/packages/01_auth-profile/build ./packages/01_auth-profile/build

EXPOSE 3001

ENV NODE_ENV=production

CMD ["node", "packages/01_auth-profile/build/index.js"]
