FROM eclipse-temurin:17-jdk AS build
WORKDIR /workspace
ARG MODULE
COPY . .
RUN --mount=type=cache,target=/root/.gradle \
    sed -i 's/\r$//' gradlew && chmod +x gradlew && \
    module_task=$(printf '%s' "$MODULE" | tr / :) && \
    ./gradlew ":${module_task}:bootJar" --no-daemon --max-workers=2

FROM eclipse-temurin:17-jre
WORKDIR /app
ARG MODULE
COPY --from=build /workspace/${MODULE}/build/libs/*-SNAPSHOT.jar app.jar
RUN mkdir /app/data && chown 10001:10001 /app/data
USER 10001
EXPOSE 8080
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75","-jar","/app/app.jar"]
