package com.p2pchat;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class P2pChatApplication {

    public static void main(String[] args) {
        SpringApplication.run(P2pChatApplication.class, args);
    }
}
