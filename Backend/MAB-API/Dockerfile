# ============================================================
# Dockerfile — MyAccountingBooks API
# Multi-stage build:
#   Stage 1 (builder): Maven + JDK 23 — compiles and packages the JAR
#   Stage 2 (runtime): JRE 23 only    — runs the JAR, no build tools
#
# Multi-stage keeps the final image lean:
#   Builder layer is discarded after the JAR is extracted.
#   Runtime image contains only the JRE + the application JAR.
#
# Build:  docker build -t mab-api .
# Run:    docker-compose up
# ============================================================

# ── Stage 1: Build ───────────────────────────────────────────────────────────
# eclipse-temurin is the recommended OpenJDK distribution for Docker.
# Using JDK 23 to match your local development environment.
FROM eclipse-temurin:23-jdk AS builder

# Set working directory inside the builder container.
WORKDIR /build

# Copy the Maven wrapper and pom.xml first — Docker layer caching means
# dependencies are only re-downloaded when pom.xml changes, not on
# every source code change.
COPY mvnw ./
COPY .mvn .mvn
COPY pom.xml ./

# Download dependencies (cached layer — only invalidated when pom.xml changes).
# -B = batch mode (no interactive prompts)
# -q = quiet (suppress download noise in build logs)
RUN ./mvnw dependency:go-offline -B -q

# Copy source code — this layer is invalidated on every code change,
# but the dependency layer above is still cached.
COPY src ./src

# Package: compile, test, and produce the JAR.
# -DskipTests: skip tests during Docker build — run tests in CI separately.
RUN ./mvnw package -B -DskipTests

# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
# JRE only — no compiler, no Maven, no source code in the final image.
FROM eclipse-temurin:23-jre AS runtime

# Set working directory inside the runtime container.
WORKDIR /app

# Copy only the compiled JAR from the builder stage.
# The wildcard handles the version number in the filename (e.g. mab-api-0.0.1-SNAPSHOT.jar).
COPY --from=builder /build/target/*.jar app.jar

# Port 8080: must match server.port in application.properties.
EXPOSE 8080

# Activate the "docker" Spring profile — loads application-docker.properties
# on top of application.properties, overriding the datasource URL.
ENV SPRING_PROFILES_ACTIVE=docker

# JWT secret: override at runtime via docker-compose environment or
# docker run -e JWT_SECRET=... for production deployments.
# The default from application.properties is used if not overridden.
ENV JWT_SECRET=change_me_in_production_use_a_256_bit_key

# Start the application.
# Using exec form (JSON array) — correct signal handling, clean shutdown.
ENTRYPOINT ["java", "-jar", "app.jar"]
