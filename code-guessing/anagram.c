#include <immintrin.h>
#include <memory.h>
#include <stdint.h>

#define MAXLEN 512
#define M128SIZE 16
#define M128SIZEBITS 4
#define CHUNKS (MAXLEN >> M128SIZEBITS)
#define BROADCAST_EPI8(x) _mm_set_epi8(x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x)

char* run(char *m) {
    for (uint16_t i = 0; i < MAXLEN; i += M128SIZE) {
        __m128i *x = (__m128i*)(&m[i]);
        __m128i curr = *x;
        curr = _mm_add_epi8(curr, _mm_and_si128(_mm_cmpgt_epi8(curr, BROADCAST_EPI8(96)), BROADCAST_EPI8(-32)));
        int32_t match = 0;
        while (match != 0xFFFF) {
            __m128i ps = _mm_shuffle_epi8(curr, _mm_set_epi8(14, 15, 12, 13, 10, 11, 8, 9, 6, 7, 4, 5, 2, 3, 0, 1));
            __m128i sw1 = _mm_blendv_epi8(curr, ps, _mm_xor_si128(_mm_cmplt_epi8(curr, ps), _mm_set_epi8(0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1)));
            __m128i ops = _mm_shuffle_epi8(sw1, _mm_set_epi8(15, 13, 14, 11, 12, 9, 10, 7, 8, 5, 6, 3, 4, 1, 2, 0));
            __m128i sw2 = _mm_blendv_epi8(sw1, ops, _mm_xor_si128(_mm_cmplt_epi8(sw1, ops), _mm_set_epi8(0, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0)));
            match = _mm_movemask_epi8(_mm_cmpeq_epi8(sw2, curr));
            curr = sw2;
        }
        *x = curr;
    }

    char *buf = aligned_alloc(M128SIZE, MAXLEN);
    if (!buf) exit(1);
    memset(buf, 0, MAXLEN);
    uint8_t pos[CHUNKS] = {0};
    uint16_t opos = 0;
    while (1) {
        uint8_t max = 255;
        uint8_t bc = 255;
        for (uint16_t i = 0; i < MAXLEN; i += M128SIZE) {
            uint8_t chunk = i >> M128SIZEBITS;
            uint8_t icpos = pos[chunk];
            char v = m[icpos + i];
            if (v < max && icpos < M128SIZE) {
                max = v;
                bc = chunk;
            }
        }
        if (bc == 255) break;
        pos[bc]++;
        if (max > ' ') {
            buf[opos] = max;
            opos++;
        }
    }
    return buf;
}

uint8_t entry(char *s1, char *s2) {
    char *m1 = aligned_alloc(M128SIZE, MAXLEN);
    if (!m1) exit(1);
    char *m2 = aligned_alloc(M128SIZE, MAXLEN);
    if (!m2) exit(1);
    memset(m1, 0, MAXLEN);
    memset(m2, 0, MAXLEN);
    strncpy(m1, s1, MAXLEN);
    strncpy(m2, s2, MAXLEN);
    
    char *x1 = run(m1);
    char *x2 = run(m2);    
    free(m1);
    free(m2);

    uint8_t result = !strncmp(x1, x2, MAXLEN);
    free(x1);
    free(x2);

    return result;
}
