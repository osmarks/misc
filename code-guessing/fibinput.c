#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <complex.h>
#include <string.h>
#include <stdlib.h>

#define nfibs 93

int64_t fibs[nfibs] = {0, 1, 0};

void initf() {
	for (int k = 2; k < nfibs; k++) {
		fibs[k] = fibs[k-1] + fibs[k-2];
	}
}

bool iusol[nfibs] = {0};

int bsectf(int64_t n, int aa, int b) {
	while (aa < b) {
		int mid = (aa + b) >> 1;
		if (fibs[mid] < n) { aa = mid + 1; }
		else { b = mid; }
	}
	return aa;
}

int sumf(int64_t trg) {
	int pt = bsectf(trg, 0, nfibs);
	if (fibs[pt] == trg) {
		iusol[pt] = true;
		return 1;
	}
	for (int k = pt - 1; k > 1; k--) {
		if (iusol[k]) continue;
		iusol[k] = true;
		if (sumf(trg - fibs[k])) return 1;
		iusol[k] = false;
	}
	return 0;
}

long*f(int64_t trg, int*length) {
	if (fibs[2] == 0) initf();
	memset(iusol, 0, nfibs);
	sumf(trg);
	*length = 0;
	for (int k = 0; k < nfibs; k++) {
		if (iusol[k]) {
			(*length)++;
		}
	}
	int j = 0;
	long*out = calloc(*length, sizeof(uint64_t));
	for (int k = 0; k < nfibs; k++) {
		if (iusol[k]) {
			out[j] = k;
			j++;
		}
	}
	return out;
}

int main() {
	initf();
	for (int k = 0; k < 100; k++) {
		sumf(1);
		sumf(2);
	}
}