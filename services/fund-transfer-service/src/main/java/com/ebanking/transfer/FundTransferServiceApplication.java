package com.ebanking.transfer;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.openfeign.EnableFeignClients;
@EnableFeignClients @SpringBootApplication public class FundTransferServiceApplication { public static void main(String[] args) { SpringApplication.run(FundTransferServiceApplication.class, args); } }
