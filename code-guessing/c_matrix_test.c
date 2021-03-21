#include <stdlib.h>

int* entry(int* m1, int* m2, int n) {
    int* out = malloc(n * n * sizeof(int));
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            int total = 0;
            for (int k = 0; k < n; k++) {
                total += m1[i * n + k] * m2[k * n + j];
            }
            out[i * n + j] = total;
        }
    }
    return out;
}