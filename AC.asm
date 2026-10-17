org 100h

section .text

start:
    ; Set Video Mode 13h (320x200, 256 colors)
    mov ax, 0013h   
    int 10h         

game_loop:
    ; --- VSYNC TIMING ---
    mov dx, 03DAh   
vsync_1:
    in al, dx
    test al, 8
    jnz vsync_1     
vsync_2:
    in al, dx
    test al, 8
    jz vsync_2      

    ; --- PHYSICS ENGINE SECTION ---
    ; Apply Gravity to Vertical Velocity
    mov ax, [velocity_y]
    add ax, [gravity]
    mov [velocity_y], ax

    ; Apply Velocity to Player Y Position
    mov bx, [player_y]
    add bx, ax
    mov [player_y], bx

    ; Ground Collision Check (Floor at Y = 160)
    cmp bx, 160
    jl skip_ground_collision
    mov bx, 160
    mov [player_y], bx          ; Snap to ground
    mov word [velocity_y], 0    ; Stop falling
    mov byte [is_jumping], 0    ; Reset jump status

skip_ground_collision:

    ; --- OBSTACLE PHYSICS ---
    mov ax, [obs_x]
    sub ax, [obs_speed]        ; Move obstacle left
    cmp ax, -8                  ; Has it fully left the screen?
    jg save_obs_x
    mov ax, 320                 ; Respawn at the right edge
save_obs_x:
    mov [obs_x], ax

    ; --- INPUT / CONTROLS SECTION ---
read_keyboard:
    mov ah, 01h     ; Check if key is pressed in buffer
    int 16h         
    jz near_render  ; If no key pressed, step to rendering

    mov ah, 00h     ; Consume the key press
    int 16h         

    cmp al, 27      ; ESC Key
    je near_exit    

    cmp ah, 48h     ; UP Arrow (Jump)
    je near_jump
    cmp ah, 4Bh     ; LEFT Arrow
    je near_left
    cmp ah, 4Dh     ; RIGHT Arrow
    je near_right

near_render:
    jmp render_scene   

; --- NEAR ROUTING TABLE ---
near_exit:
    jmp exit_game
near_jump:
    jmp trigger_jump
near_left:
    jmp move_left
near_right:
    jmp move_right

trigger_jump:
    cmp byte [is_jumping], 0
    je do_jump         
    jmp render_scene   

do_jump:
    mov byte [is_jumping], 1
    mov word [velocity_y], -6 
    jmp render_scene

move_left:
    mov ax, [player_x]
    sub ax, 4          
    cmp ax, 0
    jge save_left
    mov ax, 0          
save_left:
    mov [player_x], ax
    jmp render_scene

move_right:
    mov ax, [player_x]
    add ax, 4          
    cmp ax, 312        ; 320 - 8 (width of player block)
    jle save_right
    mov ax, 312        
save_right:
    mov [player_x], ax
    jmp render_scene

    ; --- RENDER SECTION (Double Buffering) ---
render_scene:
    ; 1. Clear Virtual Buffer (Black background)
    mov ax, cs
    mov es, ax
    mov di, db_buffer
    mov ax, 0       
    mov cx, (320*200) / 2 
clear_loop:
    mov [es:di], ax
    add di, 2
    loop clear_loop

    ; 2. Draw Floor Line inside the Buffer at Y=161
    mov di, db_buffer + (161 * 320)
    mov al, 0Fh     ; Color 15 = White
    mov cx, 320
draw_ground:
    mov [es:di], al
    inc di
    loop draw_ground

    ; 3. Draw Player 8x8 Box Character (Bright Red)
    mov ax, 320
    mov dx, [player_y] 
    mul dx             
    add ax, [player_x] 
    mov di, db_buffer
    add di, ax          
    
    mov al, 0Ch         ; Color 12 = Bright Red
    mov dx, 8           
draw_player_row:
    mov cx, 8           
draw_player_pixel:
    mov [es:di], al
    inc di
    loop draw_player_pixel
    add di, 320 - 8     
    dec dx
    jnz draw_player_row

    ; 4. Draw Obstacle 8x8 Box Character (Green)
    ; Check if obstacle is partially on screen (x >= 0)
    mov ax, [obs_x]
    cmp ax, 0
    jl skip_obs_render  ; Skip simple rendering if partially off-screen left
    cmp ax, 312
    jg skip_obs_render  ; Skip if partially off-screen right
    
    mov ax, 320
    mov dx, [obs_y]
    mul dx
    add ax, [obs_x]
    mov di, db_buffer
    add di, ax

    mov al, 02h         ; Color 2 = Green
    mov dx, 8
draw_obs_row:
    mov cx, 8
draw_obs_pixel:
    mov [es:di], al
    inc di
    loop draw_obs_pixel
    add di, 320 - 8
    dec dx
    jnz draw_obs_row

skip_obs_render:

    ; 5. Blit Buffer to VRAM (Copy db_buffer to 0A000h)
    push ds             
    mov ax, cs          
    mov ds, ax          
    mov si, db_buffer   
    
    mov ax, 0A000h      
    mov es, ax          
    xor di, di          
    
    mov cx, (320*200) / 2
    rep movsw           
    pop ds              

    jmp game_loop       

exit_game:
    ; Restore text mode (Mode 3)
    mov ax, 0003h   
    int 10h
    ; Terminate Process
    mov ax, 4C00h   
    int 21h

section .data
    player_x    dw 160
    player_y    dw 100
    velocity_y  dw 0
    gravity     dw 1   
    is_jumping  db 0   

    ; Obstacle Variables
    obs_x       dw 300
    obs_y       dw 160 ; Placed right on the ground floor
    obs_speed   dw 3   ; Moving 3 pixels per frame

section .bss
    db_buffer   resb 320*200 
