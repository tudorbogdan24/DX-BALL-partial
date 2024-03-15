.586
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern printf: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Proiect  DX-Ball",0
area_width EQU 640
area_height EQU 480
area DD 0
a dd 30

counter DD 0 ; numara evenimentele de tip timer

; Plank active states
planksActive db 24 dup(1) ; 1 for active planks, 0 for inactive (deleted) planks.

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

symbol_width DD 10
symbol_height DD 20
const dd 5

paletPosX dd 276
paletPosY dd 440

ballPosX dd 250
ballPosY dd 200

ballSpeedX dd 5
aux1 dd ?

gmover dd 0

ballSpeedY dd 5
total dd 24

pozitiiPlanks dd 105, 65
		dd 175, 65
		dd 245, 65
		dd 315, 65
		dd 385, 65
		dd 455, 65
		
		dd 105, 105
		dd 175, 105
		dd 245, 105
		dd 315, 105
		dd 385, 105
		dd 455, 105
		
		dd 105, 145
		dd 175, 145
		dd 245, 145
		dd 315, 145
		dd 385, 145
		dd 455, 145
		
		dd 105, 185
		dd 175, 185
		dd 245, 185
		dd 315, 185
		dd 385, 185
		dd 455, 185




include digits.inc
include letters.inc
include simbols.inc
include ball.inc

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
				
	mov symbol_width, 10
	mov symbol_height, 20
	
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
	
make_digit:
	
	cmp eax, '_'
	je player
	
	cmp eax, '#'
	je plank
	
	cmp eax, '*'
	je ball
	

	cmp eax, '0'
	jl make_space
	
	cmp eax, '9'
	jg make_space
	
	
	sub eax, '0'
	lea esi, digits
	
	jmp draw_text

	
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	jmp draw_text

plank:
	mov eax, 1
	lea esi, palette
	mov symbol_width, 48
	mov symbol_height, 10
	jmp draw_text
	
player:
	mov eax, 0
	lea esi, palette
	mov symbol_width, 48
	mov symbol_height, 10
	jmp draw_text
	
ball:
	mov eax, 0
	lea esi, ballData
	mov symbol_width, 10
	mov symbol_height, 10
	jmp draw_text
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
	
	
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
	
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	
	cmp byte ptr [esi], 2
	je simbol_2
	
	cmp byte ptr [esi], 3
	je simbol_3
	
	mov dword ptr [edi], 0808080h
	jmp simbol_pixel_next
	
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
	jmp simbol_pixel_next
	
simbol_2:
	mov dword ptr [edi], 0582900h
	jmp simbol_pixel_next
	
simbol_3:
	mov dword ptr [edi], 0808080h
	jmp simbol_pixel_next
	
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
	
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

line_vertical macro x, y, len, color
local bucla
	mov eax, y
	mov ebx, area_width
	mul ebx
	add eax, x 
	shl eax, 2
	add eax, area
	
	mov ecx, len
	
bucla:
	mov dword ptr[eax], color
	add eax, area_width * 4
	loop bucla
endm

line_horizontal macro x, y, len, color
local bucla
	mov eax, y
	mov ebx, area_width
	mul ebx
	add eax, x
	shl eax, 2
	add eax, area
	
	mov ecx, len
	
bucla:
	mov dword ptr[eax], color
	add eax, 4
	loop bucla
endm

; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click, 3 - s-a apasat o tasta)
; arg2 - x (in cazul apasarii unei taste, x contine codul ascii al tastei care a fost apasata)
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp + arg1]
	cmp eax, 3
	je pauseScreen
	
	mov eax, [ebp + arg1]
	cmp eax, 1
	je pauseScreen
	jmp skipgameover
	pauseScreen:
		mov eax, 0
		mov gmover, eax
	skipgameover:
	
	mov eax, [ebp+arg2]
	
	cmp eax, 041h
	je moveLeft
	
	cmp eax, 044h
	je moveRight
	
	cmp eax, 052h
	je reset
	
	jmp evt_click

    
	
moveLeft: ; mutare player stanga
	cmp paletPosX, 110
	jle final_draw
	sub paletPosX, 10
	jmp final_draw

moveRight: ; mutare player dreapta
	cmp paletPosX, 455
	jge final_draw
	add paletPosX, 10
	jmp final_draw

changeVelocityX: ; schimbare viteza pe axa X => X <= -X
	mov eax, 0
	sub eax, ballSpeedX
	mov ballSpeedX, eax
	jmp changePosBall
	
changeVelocityY: ; schimbare viteza pe axa Y => Y <= -Y
	mov eax, 0
	sub eax, ballSpeedY
	mov ballSpeedY, eax
	jmp changePosBall
	
gameover:
	mov gmover, 1
	
	

beyondPlankX:
    ; Assuming plankWidth is the width of a plank
    mov ebx, 48 ; Width of the plank
    add eax, ebx ; Add the width to the plank's X position to get its right edge
    cmp ballPosX, eax ; Compare the ball's X position to the right edge of the plank
    jle nextPlank ; If the ball's X is less than or equal to the right edge, it's a potential collision
    ; If the ball's X is greater, it's beyond the right edge of the plank, no collision
    jmp skipPlank ; No collision detected, skip this plank

beyondPlankY:
    ; Assuming plankHeight is the height of a plank
    mov ebx, 10 ; Height of the plank
    add edx, ebx ; Add the height to the plank's Y position to get its bottom edge
    cmp ballPosY, edx ; Compare the ball's Y position to the bottom edge of the plank
    jle nextPlank ; If the ball's Y is less than or equal to the bottom edge, it's a potential collision
    ; If the ball's Y is greater, it's beyond the bottom edge of the plank, no collision
    jmp skipPlank ; No collision detected, skip this plank

nextPlank:
    add esi, 8 ; Move to the next plank's position
    inc edi ; Move to the next plank's active state
    loop collisionLoop

	; Rendering Planks - Adjust this part within your rendering loop
    mov ecx, 24 ; Number of planks
    lea esi, pozitiiPlanks ; Plank positions
    lea edi, planksActive ; Plank active states


skipPlankRendering:
    add esi, 8 ; Move to the next plank position
    inc edi ; Move to the next plank active state
    loop renderPlanksLoop

	
reset: ; resetarea parametrilor la default
	mov paletPosX, 280
	mov paletPosY, 440
	mov ballPosX, 300
	mov ballPosY, 400
	mov ballSpeedX, 5
	mov ballSpeedY, -5	
	
	jmp final_draw
	
	
evt_click:

	mov edi, area
	mov ecx, area_height
bucla_linii:
	push ecx
	mov ecx, area_width
	
bucla_coloane:
	mov eax, 0FFFFFFh
	mov [edi], eax
	
	add edi, 4
	loop bucla_coloane
	pop ecx
	loop bucla_linii
	
evt_timer:
	inc counter
	
afisare_litere:
	
	mov ebx, 10
	mov eax, counter
	; cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 55, 150
	; cifra zecilor                
	mov edx, 0                     
	div ebx                        
	add edx, '0'                   
	make_text_macro edx, area, 45, 150
	; cifra sutelor                
	mov edx, 0                     
	div ebx                        
	add edx, '0'  
   
	make_text_macro edx, area, 35, 150
	
	make_text_macro 'S', area, 30, 170
	make_text_macro 'C', area, 40, 170
	make_text_macro 'O', area, 50, 170
	make_text_macro 'R', area, 60, 170
	
	make_text_macro 'B', area, 10, 330
	make_text_macro 'O', area, 20, 330
	make_text_macro 'G', area, 30, 330
	make_text_macro 'D', area, 40, 330
	make_text_macro 'A', area, 50, 330
	make_text_macro 'N', area, 60, 330
	
	
	make_text_macro 'T', area, 10, 350
	make_text_macro 'U', area, 20, 350
	make_text_macro 'D', area, 30, 350
	make_text_macro 'O', area, 40, 350
	make_text_macro 'R', area, 50, 350
	
	
	mov eax, 0
	cmp gmover, eax
	je skipgmover 
	
	   mov counter, 0
	    
		make_text_macro 'G', area, 320, 200
	    make_text_macro 'A', area, 330, 200
	    make_text_macro 'M', area, 340, 200
	    make_text_macro 'E', area, 350, 200
	
	
	    make_text_macro 'O', area, 370, 200
	    make_text_macro 'V', area, 380, 200
	    make_text_macro 'E', area, 390, 200
	    make_text_macro 'R', area, 400, 200
		jmp final_draw
	skipgmover:
	
	make_text_macro '_', area, paletPosX, paletPosY ;afisare player
	line_vertical 100, 0, area_height, 0
	line_vertical 505  , 0, area_height, 0
	line_horizontal 100, 450, 405, 0FF0000h
	line_horizontal 100, 451, 405, 0FF0000h
	line_horizontal 100, 452, 405, 0FF0000h
	line_horizontal 100, 453, 405, 0FF0000h
	line_horizontal 100, 454, 405, 0FF0000h
	line_horizontal 100, 455, 405, 0FF0000h
	line_horizontal 100, 456, 405, 0FF0000h
	line_horizontal 100, 457, 405, 0FF0000h
	line_horizontal 100, 458, 405, 0FF0000h
	line_horizontal 100, 459, 405, 0FF0000h
                               
	line_horizontal 100, 460, 405, 0FF0000h
	line_horizontal 100, 461, 405, 0FF0000h
	line_horizontal 100, 462, 405, 0FF0000h
	line_horizontal 100, 463, 405, 0FF0000h
	line_horizontal 100, 464, 405, 0FF0000h
	line_horizontal 100, 465, 405, 0FF0000h
	line_horizontal 100, 466, 405, 0FF0000h
	line_horizontal 100, 467, 405, 0FF0000h
	line_horizontal 100, 468, 405, 0FF0000h
	line_horizontal 100, 469, 405, 0FF0000h
	                           
	line_horizontal 100, 470, 405, 0FF0000h
	line_horizontal 100, 471, 405, 0FF0000h
	line_horizontal 100, 472, 405, 0FF0000h
	line_horizontal 100, 473, 405, 0FF0000h
	line_horizontal 100, 474, 405, 0FF0000h
	line_horizontal 100, 475, 405, 0FF0000h
	line_horizontal 100, 476, 405, 0FF0000h
	line_horizontal 100, 477, 405, 0FF0000h
	line_horizontal 100, 478, 405, 0FF0000h
	line_horizontal 100, 479, 405, 0FF0000h

	
	;afisare planks
	mov ecx, 24
	lea esi, pozitiiPlanks
	plnk:
		mov eax, [esi] ; x-ul plank-ului curent
		add esi, 4
		
		mov ebx, [esi] ; y-ul plank-ului curent
		make_text_macro '#', area, eax, ebx
		add esi, 4
	loop plnk
	
	mov ecx, 24
	lea esi, pozitiiPlanks
	
	;ball - walls
	cmp ballPosX, 100
	jle changeVelocityX
	
	cmp ballPosX, 500
	jge changeVelocityX
	
	cmp ballPosY, 0
	je changeVelocityY
	
	cmp ballPosY, 470 ; daca ajunge jos, dam reset
	jge gameover
	
	;ball - player
	mov eax, paletPosX
	cmp ballPosX, eax
	jl changePosBall
	
	
	mov eax, ballPosX
	add eax, 10
	
	mov ebx, paletPosX
	add ebx, 48
	
	cmp eax, ebx
	jg changePosBall
	
	
	mov eax, ballPosY
	add eax, 10
	
	cmp eax, paletPosY
	jne changePosBall
	
	mov eax, ballPosX
	mov ebx, paletPosX
	add eax, 5
	
	cmp ballPosX, ebx
	jg changeVelocityY
	
	mov ecx, 0
	sub ecx, ballSpeedX
	mov ballSpeedX, ecx
	jmp changeVelocityY

changePosBall:
	mov eax, ballSpeedX
	add ballPosX, eax
	mov eax, ballSpeedY
	add ballPosY, eax
	
	make_text_macro '*', area, ballPosX, ballPosY

final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

; aici colision
checkPlankCollision proc
    mov ecx, 24 ; Number of planks
    lea esi, pozitiiPlanks ; Points to the planks' positions
    lea edi, planksActive ; Points to the planks' active states

collisionLoop:
    test byte ptr [edi], 1 ; Check if the plank is active
    jz nextPlank ; Skip 

    
    mov eax, [esi] 
    mov edx, [esi + 4] ;

    
    cmp ballPosX, eax
    jl nextPlank 
    add eax, 48 ; Add plank width
    cmp ballPosX, eax
    jge nextPlank 

    cmp ballPosY, edx
    jl nextPlank 
    add edx, 10 
    cmp ballPosY, edx
    jge nextPlank 

    ; Collision detected, mark this plank as inactive
    mov byte ptr [edi], 0

nextPlank:
    add esi, 8 ; Move to the next plank's position
    inc edi ; Move to the next plank's active state
    loop collisionLoop
    ret
checkPlankCollision endp
	
	
start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start
