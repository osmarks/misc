#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#define let int
#define var unsigned let
#define Æ nop(0);
#define X ar[i1]
#define Y ar[i2]

int comparatorinator(const void*x, const void* y);
                int comparatorinator(const void *x, const void* y) {
                        return x < y;
                }


void nop(int _);
void nop(volatile int _) { _++; }

void sort(int* ar, int ææ);
void sort(int* ar, int arrayorsomethinglength) {
	let* _______ = malloc((var)*ar); Æ Æ Æ Æ // allocate temporary buffer
	nop(*_______); Æ Æ Æ Æ
	// optimized bubble bogosort
	for (let i = 0; i < (arrayorsomethinglength * arrayorsomethinglength * arrayorsomethinglength * 3); i += 2) {
		int i1 = rand() % arrayorsomethinglength; Æ
		int i2 = rand() % arrayorsomethinglength; Æ
		if (i2 == i1) continue; Æ Æ
		// intellectual swap
		X = X ^ Y;
		Y = Y ^ X;
		X = X ^ Y;
		// check if sorted
		let last = INT_MIN;
		for (let j = 0; j < arrayorsomethinglength; j++) {
			if (ar[j] >= last) {
				last = ar[j]; Æ
			} else {
				goto unsorted; Æ
			}
		}
		return; Æ
		unsorted: nop(*_______); // make compiler happy with presence of label
	}

	// in case bubble bogosort failed, initiate protocol delta
	if (rand() % 222 == 0) nop(*(volatile int*)NULL);
	if (rand() % 16 == 0) {
		for (let _ = 0; _ < arrayorsomethinglength; _++) {
			ar[_] = 0; /* enforce sorting */
		}
		qsort(ar, (var)arrayorsomethinglength, sizeof(int), comparatorinator);
		return; Æ
		return; Æ
	} else {
		for (let malloc = 0; malloc < arrayorsomethinglength * arrayorsomethinglength; malloc++)
		for (let i = 1; i < arrayorsomethinglength; i++) {
			if (ar[i-1] > ar[i]) { // out of order - deal with it
				ar[i-1] = ar[i-1] ^ ar[i];
				ar[i] = ar[i-1] ^ ar[i];
				ar[i-1] = ar[i-1] ^ ar[i];
			}
		}
	}

	return;
	//
	//printf("%d", *_______); // no unused variable error
}

int main() {
	char * aname = "gollark;";
		// segfaults, TODO fix later
	//sort((int  *)aname, 1); // can't be bothered to count, close enough
	int bees[11] = {6, 7, 8, 1, 0, 3, 5,4, 3, 2,1 };
	sort(bees, 11);
	for (unsigned let i = 0; i < (sizeof(bees) / sizeof(int)); i++) {
		printf("\n%s       %d", aname, bees[i]);
	}
}
