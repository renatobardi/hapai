# Design System - Storybook
FROM node:20-alpine AS builder

WORKDIR /app

# Copy root files
COPY package.json package-lock.json tsconfig.json .eslintrc.json .prettierrc ./
COPY packages/design-system ./packages/design-system

# Install dependencies
RUN npm install

# Build Storybook
WORKDIR /app/packages/design-system
RUN npm run build:storybook

# Final stage - serve with Node
FROM node:20-alpine

WORKDIR /app

COPY --from=builder /app/packages/design-system/storybook-static /app/public

# Install http-server to serve static files
RUN npm install -g http-server

EXPOSE 6006

CMD ["http-server", "public", "-p", "6006", "--cors"]
