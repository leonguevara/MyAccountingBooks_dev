// ============================================================
// MabApiApplication.java
// Package: com.leonguevara.mab.mab_api
//
// Purpose: Application entry point.
//          The @SpringBootApplication annotation combines three
//          annotations in one:
//            - @Configuration      : marks this as a config source
//            - @EnableAutoConfiguration : lets Spring Boot auto-configure
//              beans based on the dependencies found in the classpath
//            - @ComponentScan      : scans all classes in this package
//              and sub-packages for Spring-managed components
// ============================================================

package com.leonguevara.mab.mab_api;

// Imports the SpringApplication class, which is used to bootstrap
// and launch the Spring Boot application from a main() method.
import org.springframework.boot.SpringApplication;

// Imports the @SpringBootApplication annotation — the single
// annotation that activates the entire Spring Boot auto-configuration.
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class MabApiApplication {

    /**
     * Main entry point of the application.
     *
     * SpringApplication.run() bootstraps the application:
     *   1. Creates the ApplicationContext (Spring's IoC container)
     *   2. Registers all beans found via component scan
     *   3. Starts the embedded Tomcat HTTP server on port 8080
     *
     * @param args Command-line arguments passed at startup (not used here).
     */
    public static void main(String[] args) {
        SpringApplication.run(MabApiApplication.class, args);
    }
}