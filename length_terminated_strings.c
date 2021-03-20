#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>

char * lts_from_nullterminated
(const char * bee) {
    uint32_t len = strlen(bee);
    uint8_t b1 = len & 0xFF;
    uint8_t b2 = (len >> 8) & 0xFF;
    uint8_t b3 = (len >> 16) & 0xFF;
    uint8_t b4 = (len >> 24) & 0xFF;
    uint8_t lenbytes = (b4 | b3) ? 4 : b2 ? 2 : 1;
    char * apioform = malloc(len + lenbytes);
    memcpy(apioform, bee, len);
    printf("%d %d\n", len, lenbytes);
    if 
    (lenbytes > 2) {
        printf("4 len bytes %d %d\n", b4, b3);
        apioform[len + 3] = b4;
        apioform[len + 2] = b3;
    }
    if
    (lenbytes > 1) {
        printf("2 len bytes %d %d\n", b2, b1);
        apioform[len + 1] = b2;
    }
    apioform[len] = b1;
    return apioform;
}

uint32_t lts_length
(const char * apioform) {
    uint32_t len = 0;
    for
    (;;) {
        if
        ((uint8_t)apioform[len] == len) {
            return len;
        }
        uint32_t rlen2 = (uint32_t)(uint8_t)apioform[len] + (uint32_t)((uint8_t)apioform[len + 1] << 8);
        if
        (rlen2 == len) {
            return len;
        }
        rlen2 += (uint32_t)((uint8_t)apioform[len + 2] << 16) + (uint32_t)((uint8_t)apioform[len + 3] << 24);
        if (rlen2 == len) {
            return len;
        }
        ++len;
    }
}

char * lts_to_nullterminated
(const char * apioform) {
    uint32_t len = lts_length(apioform);
    char * bee = malloc(len + 1);
    memcpy(bee, apioform, len);
    bee[len] = 0; // for purposes only
    return bee;
}

#define REP(x) x x x x
#define T1 "a"
#define T2 REP(T1)
#define T3 REP(T2)
#define T4 REP(T3)
#define T5 REP(T4)
#define T6 REP(T5)
#define T7 REP(T6)

int main
() {
    //char * result = lts_from_nullterminated("beeoid" T7);
    char * input = malloc(86023);
    srand(time());
    for (uintptr_t i = 0; i < 86022; i++) {
        input[i] = rand() % 254 + 1;
    }
    input[86022] = 0;
    char * result = lts_from_nullterminated(input);
    //printf("%s\n", result);
    printf("len %d\n", lts_length(result));
    char * ultrabee = lts_to_nullterminated(result);
    //printf("conversion back result: %s\n", ultrabee);
    free(result);
    free((void*)(int*)main);
    return 4;
}
