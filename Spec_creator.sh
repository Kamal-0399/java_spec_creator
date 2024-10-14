#!/bin/bash

# Function to check if a dependency is present in the pom.xml
check_dependency() {
    local dependency=$1
    if grep -q "$dependency" "$PROJECT_DIR/pom.xml"; then
        echo "Dependency $dependency is present."
    else
        echo "Dependency $dependency is missing. Adding it now."
        add_dependency "$dependency"
    fi
}

# Function to add a dependency to the pom.xml
add_dependency() {
    local dependency=$1
    local groupId
    local artifactId
    local version

    case $dependency in
        "spring-boot-starter-web")
            groupId="org.springframework.boot"
            artifactId="spring-boot-starter-web"
            version="2.7.13"  # Use the same version as the project
            ;;
        "springdoc-openapi-starter-webmvc-ui")
            groupId="org.springdoc"
            artifactId="springdoc-openapi-starter-webmvc-ui"
            version="1.6.15"  # Compatible with Spring Boot 2.7.x
            ;;
        *)
            echo "Unknown dependency: $dependency"
            exit 1
            ;;
    esac

    # Add dependency to pom.xml before </dependencies> tag
    echo "Adding dependency $dependency to pom.xml..."
    sed -i "/<\/dependencies>/i \
<dependency>\n\
<groupId>$groupId</groupId>\n\
<artifactId>$artifactId</artifactId>\n\
<version>$version</version>\n\
</dependency>" "$PROJECT_DIR/pom.xml"

    if [ $? -eq 0 ]; then
        echo "Dependency $dependency added successfully."
    else
        echo "Failed to add dependency $dependency."
        exit 1
    fi
}

# Function to stop the application
stop_application() {
    echo "Stopping the application..."
    if [ -f app.pid ]; then
        kill $(cat app.pid)
        rm app.pid
        echo "Application stopped."
    else
        echo "No PID file found. Application might not be running."
    fi
}

# Main script
if [ $# -ne 1 ]; then
    echo "Usage: $0 <path_to_java_project>"
    exit 1
fi

PROJECT_DIR=$1

# Check if the project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Project directory $PROJECT_DIR does not exist."
    exit 1
fi

# Check for required dependencies in pom.xml
echo "Checking for required dependencies..."
check_dependency "spring-boot-starter-web"
check_dependency "springdoc-openapi-starter-webmvc-ui"

# Build and run the project
echo "Building the project..."
cd "$PROJECT_DIR" || exit
mvn clean install
if [ $? -ne 0 ]; then
    echo "Maven build failed. Exiting."
    exit 1
fi

echo "Running the project..."
mvn spring-boot:run &
echo $! > app.pid

# Wait for the application to start
sleep 30

# Extract the Swagger Json
SWAGGER_URL="http://localhost:8080/v3/api-docs"
OUTPUT_FILE="api-docs.json"

echo "Extracting Swagger Json from $SWAGGER_URL..."
curl -o "$OUTPUT_FILE" "$SWAGGER_URL"

if [ $? -eq 0 ]; then
    echo "Swagger json successfully created at $OUTPUT_FILE."
else
    echo "Failed to create Swagger Json."
    stop_application
    exit 1
fi

# Stop the application
stop_application

echo "Script completed successfully."
