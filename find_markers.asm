;============================================================================
; author:				Piotr Obst
; date:					31.12.2020
; description:			"Big" INTEL x86 project - finding 8th-type marker in
;							a BMP file with arbitrary dimensions.
;						int find_markers(unsigned char *bitmap,
;							unsigned int *x_pos, unsigned int *y_pos);
; calling convention:	cdecl
;	Violatile: EAX, ECX, EDX; Non-volatile: EBX, EDI, ESI, EBP, ESP.
;	Return value in EAX.
;	All parameters on the stack, first parameter at the lowest address.
;============================================================================

section	.text
global  find_markers

;============================================================================
find_markers:
; description: 
;	Find all 8th-type markers in a bitmap.
; arguments:
;	(ebp+8) unsigned char *bitmap
;	(ebp+12) unsigned char *x_pos
;	(ebp+16) unsigned char *y_pos
; variables:
;	ebx - *bitmap (later: first pixel address)
;	edi - bitmap width
;	esi - bitmap height
;	(esp) - current x
;	(esp+4) - current y
;	(esp+8) - number of markers
; returns:
;	-1 - validation failed. Not a bmp file
;	0 or a posivite integer - number of markers found
	
	push	ebp ;push ebp to the stack
	mov	ebp, esp
	push	ebx
	push	edi
	push	esi
	
	push	0 ;number of markers - (esp+8)
	push	0 ;current y - (esp+4)
	push	3 ;current x - (esp) (we can ommit first 3)
	
	mov	ebx, DWORD [ebp+8] ;ebx = *bitmap
	
	;file validation
	cmp	BYTE [ebx], 0x42 ;BMP marker (1/2)
	jne	error_1
	cmp	BYTE [ebx+1], 0x4d ;BMP marker (2/2)
	jne	error_1
	
	mov	edi, DWORD [ebx+18] ;bitmap width
	mov	esi, DWORD [ebx+22] ;esi = bitmap height
	mov	eax, DWORD [ebx+10] ;pixel-data offset
	add	ebx, eax ;ebx = first pixel address
	
main_markers_loop:
	mov	ecx, DWORD [esp] ;ecx = x
	mov	edx, DWORD [esp+4] ;edx = y
	push	DWORD [ebp+16] ;y_pos (address of the first empty cell)
	push	DWORD [ebp+12] ;x_pos (address of the first empty cell)
	push	ebx ;first pixel address
	push	esi ;bitmap height
	push	edi ;bitmap width
	push	edx ;y coordinate
	push	ecx ;x coordinate
	call	check_marker
	add	esp, 28 ;restore esp (pop 7 parameters)
	cmp	eax, 0
	je	main_markers_loop_marker_not_found ;check_marker didn't find a marker
	inc	DWORD [esp+8]
	add	DWORD [ebp+12], 4 ;move x_pos to next available cell
	add	DWORD [ebp+16], 4 ;move y_pos to next available cell
	
main_markers_loop_marker_not_found:
	inc	DWORD [esp] ;increment current x
	cmp	DWORD [esp], edi
	jl	main_markers_loop ;move right if image border not reached
	inc	DWORD [esp+4] ;increment current y
	mov	DWORD [esp], 3 ;move current x to beginning
	mov	ecx, esi ;ecx = bitmap height
	dec	ecx ;decrement ecx; we can ommit last 1 pixel
	cmp	DWORD [esp+4], ecx ;move up if image border nor reached
	jl	main_markers_loop
	
	mov	eax, DWORD [esp+8] ;return number of markers
	
exit:
	add	esp, 12 ;restore esp (pop 3 local variables)
	pop	esi
	pop	edi
	pop	ebx
	pop	ebp ;restore the initial ebp value from the stack
	ret
	
error_1: ;not a BMP file
	mov	eax, -1
	jmp	exit

;============================================================================
check_marker:
; description: 
;	Adds marker coordinates to x_pos and y_pos when marker exists at x, y.
; arguments:
;	(ebp+8) x coordinate of the marker index
;	(ebp+12) y coordinate of the marker index
;	(ebp+16) bitmap width
;	(ebp+20) bitmap height
;	(ebp+24) first pixel address
;	(ebp+28) x_pos (address of the first empty cell)
;	(ebp+32) y_pos (address of the first empty cell)
; variables:
;	ebx - horizontal arm length (x axis)
;	edi - vertical arm width (x axis)
;	esi - vertical arm length (y axis)
; returns:
;	1 - if a marker exists at (x, y)
;	0 - otherwise
	
	push	ebp ;push ebp to the stack
	mov	ebp, esp
	push	ebx
	push	edi
	push	esi
	
	mov	esi, 0 ;set vertical arm length to 0
	
	;bottom line
	push	DWORD [ebp+24] ;first pixel address
	push	DWORD [ebp+16] ;bitmap width
	push	-1 ;max length = -1 -> don't check
	push	DWORD [ebp+12] ;y coordinate
	push	DWORD [ebp+8] ;x coordinate
	call	check_line
	add	esp, 20 ;restore esp (pop 5 parameters)
	cmp	eax, 0
	je	check_marker_return_0 ;length = 0 -> marker not found
	mov	ebx, eax ;bottom line length (x axis)
	
	;space under bottom line
	cmp	DWORD [ebp+12], 0
	je	check_marker_loop ;skip if we reached the bottom edge
	mov	eax, DWORD [ebp+12] ;eax = y
	dec	eax ;move down
	push	DWORD [ebp+24] ;first pixel address
	push	DWORD [ebp+16] ;bitmap width
	push	ebx ;max length = length of the previous line
	push	eax ;y coordinate
	push	DWORD [ebp+8] ;x coordinate
	call	check_x_edge
	add	esp, 20 ;restore esp (pop 5 parameters)
	cmp	eax, ebx
	jl	check_marker_return_0 ;line is shorter than previous -> marker not found
	
	;next lines (moving up) - horizontal arm
check_marker_loop:
	inc	esi ;increment vertical arm length (y-axis)
	inc	DWORD [ebp+12] ;move up
	push	DWORD [ebp+24] ;first pixel address
	push	DWORD [ebp+16] ;bitmap width
	push	ebx ;max length = length of the previous line
	push	DWORD [ebp+12] ;y coordinate
	push	DWORD [ebp+8] ;x coordinate
	call	check_line
	add	esp, 20 ;restore esp (pop 5 parameters)
	cmp	eax, ebx
	je	check_marker_loop ;length equal to last line length
	jg	check_marker_return_0 ;length greater than last line length
	cmp eax, 0
	je	check_marker_return_0 ;length equal to 0
	mov	edi, eax ;veritical arm width (x axis)
	
	;check space over the horizontal line
	mov	eax, ebx ;eax = length of the previous line
	sub	eax, edi ;eax -= vertical arm width
	mov	ecx, DWORD [ebp+8] ;ecx = x
	sub	ecx, edi ;move to the left of the vertical arm
	push	DWORD [ebp+24] ;first pixel address
	push	DWORD [ebp+16] ;bitmap width
	push	eax ;max length = eax
	push	DWORD [ebp+12] ;y coordinate
	push	ecx ;x coordinate
	call	check_x_edge
	add	esp, 20 ;restore esp (pop 5 parameters)
	mov	ecx, ebx ;ecx = length of the previous line
	sub	ecx, edi ;ecx -= vertical arm width
	cmp	eax, ecx ;compare space length with ecx
	jl	check_marker_return_0 ;space shorter than it should be -> marker not found
	
	;next lines (moving up) - vertical arm
check_marker_loop2:
	inc	esi ;increment vertical arm length (y-axis)
	inc	DWORD [ebp+12] ;move up
	mov	eax, DWORD [ebp+12] ;eax = y
	cmp	eax, DWORD [ebp+20] ;compare y with bitmap height
	jge	check_skip ;skip if we reached the top edge
	push	DWORD [ebp+24] ;first pixel address
	push	DWORD [ebp+16] ;bitmap width
	push	edi ;max length = last line length
	push	DWORD [ebp+12] ;y coordinate
	push	DWORD [ebp+8] ;x coordinate
	call	check_line
	add	esp, 20 ;restore esp (pop 5 parameters)
	cmp	eax, edi
	je	check_marker_loop2 ;length equal to last line length
	cmp	eax, 0
	je	check_space_over ;length equal to 0 - we found the end
	jmp	check_marker_return_0 ;wrong length (longer than last or shorter but non-zero)
	
	;check space over the vertical line
check_space_over:
	push	DWORD [ebp+24] ;first pixel address
	push	DWORD [ebp+16] ;bitmap width
	push	edi ;max length = vertical arm length (last line)
	push	DWORD [ebp+12] ;y coordinate
	push	DWORD [ebp+8] ;x coordinate
	call	check_x_edge
	add	esp, 20 ;restore esp (pop 5 parameters)
	cmp	eax, edi
	jl	check_marker_return_0 ;space less than the vertical arm length
	
check_skip:
	sub	DWORD [ebp+12], esi ;subtract marker height from current y to get the y marker index
	
	shl	esi, 1 ;multiply marker height by 2
	cmp	esi, ebx ;compare marker height with marker width
	jne	check_marker_return_0 ;return 0 if horizontal arm isn't exactly 2 time longer than the vertical arm
skip:
	;we found a marker! - let's save it
	mov	eax, DWORD [ebp+8] ;eax = x
	mov	ecx, DWORD [ebp+28] ;ecx = value of the x_pos pointer
	mov	DWORD [ecx], eax ;save marker x in x_pos
	mov	eax, DWORD [ebp+20] ;eax = bitmap height
	dec	eax ;eax -= 1
	sub	eax, DWORD [ebp+12] ;eax -= y; now eax is y counted from the top, not bottom
	mov	ecx, DWORD [ebp+32] ;ecx = value of the y_pos pointer
	mov	DWORD [ecx], eax ;save marker y in y_pos
	mov	eax, 1; return 1
	
check_marker_exit:
	pop	esi
	pop	edi
	pop	ebx
	pop	ebp ;restore the initial ebp value from the stack
	ret
	
check_marker_return_0:
	mov	eax, 0
	jmp	check_marker_exit

;============================================================================
check_line:
; description: 
;	Check the whole black line from right to left (starting from a pixel to the right of the marker).
; arguments:
;	(ebp+8) x coordinate of the marker index
;	(ebp+12) y coordinate of the current line
;	(ebp+16) max length (don't check length if max length = -1)
;	(ebp+20) bitmap width
;	(ebp+24) first pixel address
; variables:
;	ebx - current length
;	edi - current x coordinate
;	esi - current y coordinate
; returns:
;	length of the line (x axis)
	
	push	ebp ;push ebp to the stack
	mov	ebp, esp
	push	ebx
	push	edi
	push	esi
	
	mov	ebx, 0 ;current length = 0
	inc	DWORD [ebp+16] ;increment max length by 1
	mov	edi, DWORD [ebp+8] ;current x = x
	mov	esi, DWORD [ebp+12] ;current y = y
	
	inc	edi ;check a pixel to the right of the starting point
	mov	eax, DWORD [ebp+20] ;eax = bitmap width
	cmp	edi, eax ;if we reached the right edge, don't check
	jge	check_line_loop
	push	DWORD [ebp+24] ;first pixel
	push	eax ;bitmap width
	push	esi ;current y
	push	edi ;current x
	call	get_pixel
	add	esp, 16 ;restore esp (pop 4 parameters)
	cmp	eax, 0
	je	check_line_exit ;if color of a pixel to the right of the starting point is black, return 0
	
check_line_loop:
	dec	edi ;move left
	cmp	edi, 0
	jl	check_line_exit ;if we reached the left edge, exit
	push	DWORD [ebp+24] ;first pixel
	push	DWORD [ebp+20] ;bitmap width
	push	esi ;current y
	push	edi ;current x
	call	get_pixel
	add	esp, 16 ;restore esp (pop 4 parameters)
	cmp	eax, 0
	jne	check_line_exit ;if color of the current pixel is not black, exit
	inc	ebx ;increment current length
	cmp	ebx, DWORD[ebp+16]
	je	check_line_exit ;if length is equal to max length, exit
	jmp	check_line_loop
	
check_line_exit:
	mov	eax, ebx ;return current length
	pop	esi
	pop	edi
	pop	ebx
	pop	ebp ;restore the initial ebp value from the stack
	ret

;============================================================================
check_x_edge:
; description: 
;	Check the whole edge (non-black line) from right to left.
; arguments:
;	(ebp+8) x coordinate of the marker index
;	(ebp+12) y coordinate of the current line
;	(ebp+16) max length (don't check length if max length = -1)
;	(ebp+20) bitmap width
;	(ebp+24) first pixel address
; variables:
;	ebx - current length
;	edi - current x coordinate
;	esi - current y coordinate
; returns:
;	length of the line (x axis)
	
	push	ebp ;push ebp to the stack
	mov	ebp, esp
	push	ebx
	push	edi
	push	esi
	
	mov	ebx, 0 ;current length = 0
	mov	edi, DWORD [ebp+8] ;current x = x
	mov	esi, DWORD [ebp+12] ;current y = y
	
check_x_edge_loop:
	cmp	edi, 0
	jl	check_x_edge_exit ;if we reached the left edge, exit
	push	DWORD [ebp+24] ;first pixel
	push	DWORD [ebp+20] ;bitmap width
	push	esi ;current y
	push	edi ;current x
	call	get_pixel
	add	esp, 16 ;restore esp (pop 4 parameters)
	cmp	eax, 0
	je	check_x_edge_exit ;if color of the current pixel is black, exit
	inc	ebx ;increment current length
	cmp	ebx, DWORD[ebp+16]
	je	check_x_edge_exit ;if length is equal to max length, exit
	dec	edi ;move left
	jmp	check_x_edge_loop
	
check_x_edge_exit:
	mov	eax, ebx ;return current length
	pop	esi
	pop	edi
	pop	ebx
	pop	ebp ;restore the initial ebp value from the stack
	ret

;============================================================================
get_pixel:
; description: 
;	Returns 0 if pixel is black, other values if it is not black.
;		It does not return the pixel color! (for optimisation)
; arguments:
;	(ebp+8) x coordinate
;	(ebp+12) y coordinate
;	(ebp+16) width
;	(ebp+20) index of the first pixel in bitmap
; returns:
;	0 - if pixel is black
;	other values -  if it is not black
	
	push	ebp ;push ebp to the stack
	mov	ebp, esp
	
	mov	eax, DWORD [ebp+16] ;eax = width
	and	eax, 3 ;eax %= 4
	mov	ecx, DWORD [ebp+16] ;ecx = width
	add	eax, ecx ;eax += width (adding 3 times is faster than multiplying by 3)
	add	eax, ecx
	add	eax, ecx ;(now eax = width*3 + padding)
	mul	DWORD [ebp+12] ;eax = y*BYTES_PER_ROW
	mov	ecx, eax ;ecx = eax
	mov	eax, DWORD [ebp+8] ;eax = x
	add	ecx, eax ;ecx += x (adding 3 times is faster than multiplying by 3)
	add	ecx, eax
	add	ecx, eax ;now eax = x + y*BYTES_PER_ROW
	add	ecx, DWORD [ebp+20] ;ecx now holds index of the BLUE value
	
	mov	eax, 0
	mov	al, BYTE [ecx] ;load BLUE
	mov	ah, BYTE [ecx+1] ;load GREEN
	cmp	eax, 0
	jne	get_pixel_exit
	mov	al, BYTE [ecx+2] ;load RED
	
get_pixel_exit:
	pop	ebp ;restore the initial ebp value from the stack
	ret

;============================================================================
