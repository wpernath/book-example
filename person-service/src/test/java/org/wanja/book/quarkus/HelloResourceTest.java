package org.wanja.book.quarkus;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;

import org.eclipse.microprofile.config.inject.ConfigProperty;

@QuarkusTest
public class HelloResourceTest {

    @ConfigProperty(name = "app.greeting")
    String greeting;

    @Test
    public void testHelloEndpoint() {
        given()
          .when().get("/hello")
          .then()
             .statusCode(200)
             .body(is(greeting));
    }

}