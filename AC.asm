org 100h

section .text

start:
    mov ax, 0013h   
    int 10h         

game_loop:
    mov dx, 03DAh   
vsync_1:
    in al, dx
    test al, 8
    jnz vsync_1     
vsync_2:
    in al, dx
    test al, 8
    jz vsync_2      

    ; --- PHYSICS ENGINE ENGINE SECTION ---
    ; Apply Gravity to Vertical Velocity
    mov ax, [velocity_y]
    add ax, [gravity]
    mov [velocity_y], ax

    ; Apply Velocity to Player Y Position
    mov bx, [player_y]
    add bx, ax
    mov [player_y], bx

    ; Ground Collision Check (Let's make Y = 160 the floor)
    cmp bx, 160
    jl skip_ground_collision
    mov bx, 160
    mov [player_y], bx          ; Snap to ground
    mov word [velocity_y], 0    ; Stop falling
    mov byte [is_jumping], 0    ; Reset jump status

skip_ground_collision:

    ; --- RENDER SECTION ---
    mov ax, 0A000h  
    mov es, ax      
    xor di, di      
    mov ax, 0       
    mov bx, 320*200 / 2 
clear_loop:
    mov [es:di], ax
    add di, 2
    dec bx
    jnz clear_loop

    ; Draw a simple white line for the Ground Floor
    ; Line spans across Y=161 from X=0 to X=319
    mov di, 161 * 320
    mov al, 0Fh     ; Color 15 = White
    mov cx, 320
draw_ground:
    mov [es:di], al
    inc di
    loop draw_ground

    ; Draw the Assassin Pixel
    mov ax, 320
    mov dx, [player_y] 
    mul dx             
    add ax, [player_x] 
    mov di, ax         
    mov al, 0Ch        ; Color 12 = Bright Red
    mov [es:di], al    

read_keyboard:
    mov ah, 01h     
    int 16h         
    jz game_loop       

    mov ah, 00h     
    int 16h         

    cmp al, 27         
    je exit_game    

    cmp ah, 48h        ; UP Arrow (Jump)
    je trigger_jump
    cmp ah, 4Bh        ; LEFT Arrow
    je move_left
    cmp ah, 4Dh        ; RIGHT Arrow
    je move_right
    jmp game_loop   

trigger_jump:
    cmp byte [is_jumping], 0
    jne game_loop      ; If already jumping, ignore
    mov byte [is_jumping], 1
    mov word [velocity_y], -6 ; Give an upward negative thrust
    jmp game_loop

move_left:
    mov ax, [player_x]
    sub ax, 4          ; Move 4 pixels left
    cmp ax, 0
    jl game_loop
    mov [player_x], ax
    jmp game_loop

move_right:
    mov ax, [player_x]
    add ax, 4          ; Move 4 pixels right
    cmp ax, 315
    jg game_loop
    mov [player_x], ax
    jmp game_loop

exit_game:
    mov ax, 0003h   
    int 10h
    mov ax, 4C00h   
    int 21h

section .data
    player_x    dw 160
    player_y    dw 100
    velocity_y  dw 0
    gravity     dw 1   ; Downward acceleration rate
    is_jumping  db 0   ; Boolean flag (0=No, 1=Yes)
