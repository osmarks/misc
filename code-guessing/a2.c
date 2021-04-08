#include <stdio.h>
#include <immintrin.h>
#include <memory.h>
#include <time.h>

#define MAXLEN 512
#define M128SIZE 16
#define CHUNKS (MAXLEN / M128SIZE)

int entry(char *s1, char *s2) {
    char *m1 = aligned_alloc(M128SIZE, MAXLEN);
    char *m2 = aligned_alloc(M128SIZE, MAXLEN);
    strncpy(m1, s1, MAXLEN);
    strncpy(m2, s2, MAXLEN);
    
    for (int i = 0; i < MAXLEN; i += M128SIZE) {
        __m128i *x = (__m128i*)(&m1[i]);
        __m128i input = *x;
        __m128i perm1 = _mm_set_epi8(1, 0, 3, 2, 5, 4, 7, 6, 9, 8, 11, 10, 13, 12, 15, 14);
        __m128i pair_swapped = _mm_shuffle_epi8(input, perm1);
        __m128i comp = _mm_cmplt_epi8(input, pair_swapped);
        __m128i mask = _mm_xor_si128(comp, _mm_set_epi8(0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1, 0, -1));
        __m128i blendeded = _mm_blendv_epi8(input, pair_swapped, mask);
        __m128i perm2 = _mm_set_epi8(0, 2, 1, 4, 3, 6, 5, 8, 7, 10, 9, 12, 11, 14, 13, 15);
        __m128i opair_swapped = _mm_shuffle_epi8(input, perm2);
        __m128i comp2 = _mm_cmplt_epi8(input, opair_swapped);
        
        //*x = _mm_shuffle_epi8(input, s);
        for (int i = 0; i < 16; i++) {
            //printf("%d %c→%c / ", ((char*)&comp2)[i], ((char*)input)[i], ((char*)&opair_swapped)[i]);
            //printf("%d %c-%c", ((char*)&comp)[i], ((char*)input)[i], ((char*)&pair_swapped)[i]);
            printf("%c", ((char*)&blendeded)[i]);
        }
        printf(" %d\n", i);
    }
    
    return 0;
}

int main() {
    srand(time(NULL));
    entry("aopfmffooapfariproompoafimfafppfiopoiformrmmafoiioiommiooraomoamppoiorfammapparamoarpmpoarpoampfmrarorfirfrpoafariiroipripoooofaioairampiooopoppopoimaamroooofamrprororoirfmorormmoaooiopoooooaoaopfmiiaoaaoffofioraorffrmfoioofriraiioappipooofoaomfifopmofmafforippfamoaopiopmiafopmfmpifmaroomiopoapppforfffrmiioaapafoaorfpmffofrporoaaaopmffimomroarifimmrpfrpofofaopoapiormmopriimrmrifroofrirmmoaipmrrofoorprmpoprofapiopommopoomoariapiooraoiiampmmprpmiporoiaofrariaorppifoomarfoirfmimffofmiioooriaammiiafiooioipamofm", "fiaaafamrofafprooparomaprioifiomfofaoproooooiooorooioamfipofroommoafopaopaioppiiproirfimpiorfmaroamopmiipmoapofoaoaofiioofrormaimrpmooafiiorifimoaprrrraoiamoorpfapofffpoorppfmmffmifimofrofoaopoiorrpaaaoioipofpmimrmoooiiafproimpprifrrrrrrriromfirmrpmaompiaooommpmrriromioppoirorapoaoiiaoaioaoaofiaaoaafamraffioooiiaopofooioommoooiropopmiapfpimpoappmmfpmapofmfamrppaaomfamfpopraiamfpofrrmomaofmiaaorriofaimaoomripfpfoomoaafmfiimrfaroofpaffopromarmomopfiafoopopifimopmoroimrrmrrfmooporroioofpfomomomrorfppipffofaipp");
    printf("ALL is now bee\n");
}