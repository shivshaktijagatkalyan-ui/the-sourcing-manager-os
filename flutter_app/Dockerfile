# Build stage: use official Flutter image with stable branch
FROM ghcr.io/cirruslabs/flutter:stable AS build-env

# Set working directory
WORKDIR /app

# Copy the app files
COPY . .

# Get dependencies
RUN flutter pub get

# Build the web app
RUN flutter build web --release

# Final stage: serve the app with Docker Hardened Image (DHI) nginx
FROM dhi.io/nginx:1-alpine3.21
COPY --from=build-env /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 5050
