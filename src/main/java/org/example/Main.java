package org.example;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class Main implements CommandLineRunner {

    @Value("${secret.value:No secret found}")
    private String secret;

    public static void main(String[] args) {
        SpringApplication.run(Main.class, args);
    }

    @Override
    public void run(String... args) {
        System.out.println("--------------------------");
        // only for workshop purposes - secrets should never be printed and injected
        System.out.println("secret: " + secret);
    }
}