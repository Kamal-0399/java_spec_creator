#!/bin/bash

# Function to check if a dependency is present in the pom.xml
check_and_add_dependency() {
    local dependency=$1
    if grep -q "$dependency" "$PROJECT_DIR/pom.xml"; then
        echo "Dependency $dependency is present."
    else
        echo "Dependency $dependency is missing. Adding..."
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
            version="3.2.2" # Adjust version as needed
            ;;
        "springdoc-openapi-starter-webmvc-ui")
            groupId="org.springdoc"
            artifactId="springdoc-openapi-starter-webmvc-ui"
            version="2.6.0" # Adjust version as needed
            ;;
        *)
            echo "Unknown dependency: $dependency"
            exit 1
            ;;
    esac

    sed -i "/<\/dependencies>/i \
<dependency>\n\
<groupId>$groupId</groupId>\n\
<artifactId>$artifactId</artifactId>\n\
<version>$version</version>\n\
</dependency>" "$PROJECT_DIR/pom.xml"
}

# Function to check if a plugin is present in the pom.xml
check_and_add_plugin() {
    local plugin=$1
    if grep -q "$plugin" "$PROJECT_DIR/pom.xml"; then
        echo "Plugin $plugin is present."
    else
        echo "Plugin $plugin is missing. Adding..."
        add_plugin "$plugin"
    fi
}

# Function to add a plugin to the pom.xml
add_plugin() {
    local plugin=$1
    local groupId
    local artifactId

    case $plugin in
        "springdoc-openapi-maven-plugin")
            groupId="org.springdoc"
            artifactId="springdoc-openapi-maven-plugin"
            ;;
        "spring-boot-maven-plugin")
            groupId="org.springframework.boot"
            artifactId="spring-boot-maven-plugin"
            ;;
        *)
            echo "Unknown plugin: $plugin"
            exit 1
            ;;
    esac

    sed -i "/<\/plugins>/i \
<plugin>\n\
<groupId>$groupId</groupId>\n\
<artifactId>$artifactId</artifactId>\n\
</plugin>" "$PROJECT_DIR/pom.xml"
}

# Function to check and add required properties in application.properties
check_and_add_property() {
    local property=$1
    if grep -q "^$property" "$PROJECT_DIR/src/main/resources/application.properties"; then
        echo "Property $property is present."
    else
        echo "Property $property is missing. Adding..."
        echo "$property" >> "$PROJECT_DIR/src/main/resources/application.properties"
    fi
}

# Function to stop the application gracefully
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
check_and_add_dependency "spring-boot-starter-web"
check_and_add_dependency "springdoc-openapi-starter-webmvc-ui"

# Check for required plugins in pom.xml
echo "Checking for required plugins..."
check_and_add_plugin "springdoc-openapi-maven-plugin"
check_and_add_plugin "spring-boot-maven-plugin"

# Check for required properties in application.properties
echo "Checking for required properties..."
check_and_add_property "springdoc.version=@springdoc.version@"
check_and_add_property "springdoc.swagger-ui.use-root-path=true"
check_and_add_property "server.forward-headers-strategy=framework"

# Build and run the project
echo "Building the project..."
cd "$PROJECT_DIR" || exit
mvn clean install

echo "Running the project..."
mvn spring-boot:run &
echo $! > app.pid

# Wait for the application to start
sleep 30

# Extract the Swagger YAML
SWAGGER_URL="http://localhost:8080/v3/api-docs"
OUTPUT_FILE="api-docs.yaml"

echo "Extracting Swagger YAML from $SWAGGER_URL..."
curl -o "$OUTPUT_FILE" "$SWAGGER_URL"

if [ $? -eq 0 ]; then
    echo "Swagger YAML successfully created at $OUTPUT_FILE."
else
    echo "Failed to create Swagger YAML."
    stop_application
    exit 1
fi

# Stop the application
stop_application

echo "Script completed successfully."
