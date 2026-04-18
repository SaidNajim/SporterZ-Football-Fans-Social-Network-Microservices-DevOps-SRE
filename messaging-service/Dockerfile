FROM eclipse-temurin:17-jre-alpine
VOLUME /tmp
EXPOSE 8083
ARG JAR_FILE=target/messaging-service-1.0-SNAPSHOT.jar
ADD ${JAR_FILE} app.jar
ENTRYPOINT ["java","-jar","/app.jar"]
