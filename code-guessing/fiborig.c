#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <complex.h>
#include <string.h>
#include <stdlib.h>

#define nfibs 93
int64_t fibs[nfibs] = {0, 1, 0};

void initf() {
	for (int i = 2; i < nfibs; i++) {
		fibs[i] = fibs[i-1] + fibs[i-2];
	}
}

bool iusol[nfibs] = {0};

int bsectf(int64_t n, int a, int b) {
	while (a < b) {
		int mid = (a + b) >> 1;
		if (fibs[mid] < n) { a = mid + 1; }
		else { b = mid; }
	}
	return a;
}

int sumf(int64_t target) {
	int pt = bsectf(target, 0, nfibs);
	if (fibs[pt] == target) {
		iusol[pt] = true;
		return 1;
	}
	for (int i = pt - 1; i > 1; i--) {
		if (iusol[i]) continue;
		iusol[i] = true;
		if (sumf(target - fibs[i])) return 1;
		iusol[i] = false;
	}
	return 0;
}

long*f(int64_t target, int*length) {
	if (fibs[2] == 0) initf();
	memset(iusol, 0, nfibs);
	sumf(target);
	*length = 0;
	for (int i = 0; i < nfibs; i++) {
		if (iusol[i]) {
			(*length)++;
		}
	}
	int j = 0;
	long*out = calloc(*length, sizeof(uint64_t));
	for (int i = 0; i < nfibs; i++) {
		if (iusol[i]) {
			out[j] = i;
			j++;
		}
	}
	return out;
}

int main() {
	initf();
	for (int i = 0; i < 100; i++) {
		sumf(1);
		sumf(2);
	}
}