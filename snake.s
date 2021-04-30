setup:
	mov r1, #0x00FF00 // snake color
	mov r2, #0xFFFFFF // background color
	mov r3, #271 // tail pos
	mov r4, #272 // head pos
	mov r5, #0xFF0000 // apple color
	mov r6, #520 // apple position
	mov r7, #767 // wrap location/size of screen
	mov r8, #snake_body // front of queue - tail location location
	add r9, r8, #1 // back of queue - head location location
    mov r10, #68 // movement direction
	str r3, [r8]
	str r4, [r9]
initial_draw:
	str r1, [r3+256]
	str r1, [r4+256]
move:
	str r5, [r6+256] // draw apple
	inp r0, 4
handle_keypresses:
	cmp r0, #83 // S key
	beq go_down
	cmp r0, #65 // A key
	beq go_left
	cmp r0, #68 // D key
	beq go_right
	cmp r0, #87 // W key
	beq go_up
    mov r0, r10
    b handle_keypresses
go_right:
    cmp r10, #65 // if was left
    beq reset_key
    mov r10, r0
	add r4, r4, #1
	and r0, r4, #31
	cmp r0, #0 // note; change back if wrong
	beq rwrap
	b draw
rwrap:
	sub r4, r4, #31
	b draw
go_left:
    cmp r10, #68 // if was right
    beq reset_key
    mov r10, r0
	sub r4, r4, #1
	and r0, r4, #31
	cmp r0, #31
	beq lwrap
	b draw
lwrap:
	add r4, r4, #32
	b draw
go_up:
    cmp r10, #83 // if was down
    beq reset_key
    mov r10, r0
	sub r4, r4, #32
	cmp r4, #0
	blt uwrap
	b draw
uwrap:
	add r4, r4, #736
	b draw
go_down:
    cmp r10, #87 // if was up
    beq reset_key
    mov r10, r0
	add r4, r4, #32
	cmp r4, r7
	bgt dwrap
	b draw
dwrap:
	sub r4, r4, #736
draw:
	cmp r4, r6 // check if in apple location
	beq create_apple // do not move tail - apple attained
move_tail:
	ldr r0, [r8]
	str r2, [r0+256] // clear tail
	add r8, r8, #1 // inc tail pointer
	cmp r8, #200
	blt move_head
	mov r8, #snake_body
move_head:
	add r9, r9, #1 // inc head pointer
	cmp r9, #200
	blt actually_move_head
	mov r9, #snake_body
actually_move_head:
	str r4, [r9]
    ldr r0, [r4+256] // check if snake is self-intersecting via reading screen memory
    cmp r0, r1
    beq game_over
    cmp r8, r9 // check for win condition - head and tail in same spot means it's very long, so you win
    beq game_win
	str r1, [r4+256] // draw head
	b move // loop infinitely
create_apple:
    inp r6, 8
    mov r0, #1023 // too big for immediate parameter
    and r6, r6, r0
    cmp r6, r7
    bgt create_apple // loop again if out of range
    cmp r6, r4
    beq create_apple
    b move_head
reset_key:
    mov r0, r10
    b handle_keypresses
game_over:
    mov r0, #loss_message
    out r0, 8
    halt
game_win:
    mov r0, #win_message
    out r0, 8
    halt
loss_message:
    dat 0x20756f59 // "You "
    dat 0x65736f4c // "Lose"
    dat 0 // ␀
win_message:
    dat 0x20756f59 // "You"
    dat 0x006e6957 // "Win␀"
snake_body: dat 0