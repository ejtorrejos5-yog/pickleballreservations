# ==========================================
# Multi-stage Dockerfile for Flutter Web on Render
# ==========================================

# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy dependency files first for layer caching
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy all source files
COPY . .

# Build web in release mode
RUN flutter config --no-analytics
RUN flutter build web --release

# Stage 2: Serve with lightweight Nginx
FROM nginx:alpine

# Copy web build output to Nginx document root
COPY --from=build /app/build/web /usr/share/nginx/html

# Dynamic port template (Render automatically sets $PORT)
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

ENV PORT=10000
EXPOSE 10000

CMD ["nginx", "-g", "daemon off;"]
