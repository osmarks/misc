_mulloop := (pop warp new new new new new new new new new new warp _mulloop)
10* := warp new enter warp _mulloop exit pop warp exit send warp enter
[ := new enter
0 := 10*
1 := 10* new
2 := 10* new new
3 := 10* new new new
4 := 10* new new new new
5 := 10* new new new new new
6 := 10* new new new new new new
7 := 10* new new new new new new new
8 := 10* new new new new new new new new
9 := 10* new new new new new new new new new
] := exit
. := ] write [

main := [ 7 2 . 1 0 1 . 1 0 8 . 1 0 8 . 1 1 1 . 4 4 . 3 2 . 1 1 9 . 1 1 1 . 1 1 4 . 1 0 8 . 1 0 0 . 3 3 . 1 0 . ]