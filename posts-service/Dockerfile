FROM eclipse-temurin:17-jre-alpine
EXPOSE 8081
ARG JAR_FILE=target/posts-service-1.0-SNAPSHOT.jar
ADD ${JAR_FILE} app.jar
ENTRYPOINT ["java","-jar","/app.jar"]
