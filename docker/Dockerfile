FROM eclipse-temurin:17-jre
WORKDIR /app
ARG MODULE
COPY ${MODULE}/build/libs/*-SNAPSHOT.jar app.jar
USER 10001
EXPOSE 8080
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75","-jar","/app/app.jar"]
