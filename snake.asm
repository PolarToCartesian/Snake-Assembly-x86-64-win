    ; All exported functions for the linker
    global _start
    global _window_proc
    global _set_timer_callback

    ; All the win32 functions we need to link to
    extern GetModuleHandleA
    extern RegisterClassA
    extern DefWindowProcA
    extern CreateWindowExA
    extern ShowWindow
    extern PeekMessageA
    extern TranslateMessage
    extern DispatchMessageA
    extern DestroyWindow
    extern PostQuitMessage
    extern ExitProcess
    extern BeginPaint
    extern FillRect
    extern EndPaint
    extern CreateSolidBrush
    extern DeleteObject
    extern RedrawWindow
    extern GlobalAlloc
    extern GlobalFree
    extern AdjustWindowRect
    extern SetTimer
    extern LoadCursorA
    extern CreateIcon
    extern DestroyIcon

; Modifiable constants
%define GRID_SQUARE_SIDE_LENGTH 10 ; # pixels
%define GRID_SQUARE_SIDE_COUNT  50 ; # squares
%define FRAME_TIME              75 ; the delta-time in ms between each frame/update.

; Auto-Gnerated Constants
%define WIDTH             (GRID_SQUARE_SIDE_LENGTH*GRID_SQUARE_SIDE_COUNT) ; The width  in pixels of the window's client area
%define HEIGHT            (WIDTH)                                          ; The height in pixels of the window's client area
%define PIXEL_COUNT       (WIDTH*HEIGHT)
%define SNAKE_BUFFER_SIZE (PIXEL_COUNT * 8)                                ; The size of the buffer containg the snake's body positions' locations (X: DWORD, Y: DWORD)

; Useful Constants For x86-64 Assembly
%define SHADOW_SPACE_SIZE (20h) ; 20h=0x20=32 (bytes of shadow space).
%define WORD_SIZE         (2)   ; # bytes
%define DWORD_SIZE        (4)   ; # bytes
%define QWORD_SIZE        (8)   ; # bytes

; WIN32 Constants
%define IDC_CROSS      (32515)

%define WS_OVERLAPPED  (0x00000000)
%define WS_CAPTION     (0x00C00000)
%define WS_SYSMENU     (0x00080000)
%define WS_MINIMIZEBOX (0x00020000)
%define WS_MAXIMIZEBOX (0x00010000)

; WIN32 x64 type sizes
%define HWND_SIZE        (QWORD_SIZE)   ; # bytes
%define PAINTSTRUCT_SIZE (72)           ; # bytes
%define RECT_SIZE        (4*DWORD_SIZE) ; # bytes

; WIN32 Combined Flags
%define CUSTOM_WINDOW_DW_STYLE (WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX)

; WIN32 Brush 0x00BBGGRR Colors
%define SNAKE_BRUSH_COLOR      (0x0000FF00)
%define APPLE_BRUSH_COLOR      (0x000000FF)
%define BACKGROUND_BRUSH_COLOR (0x00000000)

    section .text

_apple_new_position: ;TODO: Random Position
    MOV  EAX, DWORD[APPLE]
    MOV  EDX, DWORD[APPLE+4]

    MOV  DWORD[APPLE],   EDX
    MOV  DWORD[APPLE+4], EAX
    RET



_update_render_game:
_update_render_game___update:
    MOV R15, QWORD[SNAKE_BUFFER_PTR]

    ; Move the rest of the body starting from the part just after the head
    MOV R9, QWORD[SNAKE_LEN]
    SHL R9, 3 ; Multiply by 8 (2 dwords): current offset

_update_render_game___move_body_loop: ; Probably doesn't work for a snake size > 2
    ; Update X
    MOV R10D, DWORD[R15+R9-8]
    MOV DWORD[R15+R9], R10D

    ; Update Y
    MOV R10D, DWORD[R15+R9-4]
    MOV DWORD[R15+R9+4], R10D

    ; Handle Loop
    SUB R9, 8
    CMP R9, 8
    JGE _update_render_game___move_body_loop

_update_render_game___move_head:
    ; Move Head X
    MOV R12D, DWORD[R15]
    ADD R12D, DWORD[SNAKE_DIR] 
    MOV DWORD[R15], R12D

    ; Move Head Y
    MOV R13D, DWORD[R15+4]
    ADD R13D, DWORD[SNAKE_DIR+4] 
    MOV DWORD[R15+4], R13D

_update_render_game___repaint:
    SUB  RSP, 32            ; Shadow Space

    MOV  RCX, QWORD[HWND]
    XOR  RDX, RDX
    XOR  R8,  R8
    MOV  R9,  1             ; RDW_INVALIDATE
    CALL RedrawWindow

    ADD  RSP, 32            ; Shadow Space

_update_render_game___apple_collision:
    ; Check If Head Intersects The Apple
    CMP R12D, DWORD[APPLE]
    JNE _update_render_game___return
    CMP R13D, DWORD[APPLE+4]
    JNE _update_render_game___return

    ; Increment the snake length
    MOV RAX, QWORD[SNAKE_LEN]
    INC RAX
    MOV QWORD[SNAKE_LEN], RAX

    CMP R12D, DWORD[APPLE]
    JNE _update_render_game___return
    CMP R13D, DWORD[APPLE+4]
    JNE _update_render_game___return

    call _apple_new_position

_update_render_game___return:
    RET




_start:
    ; Prologue
    PUSH RBP
    MOV  RBP, RSP

    SUB  RSP, 112 ; MEMORY used for RECT & WNDCLASSA + SHADOW

    ; Get HINSTANCE
    XOR  RCX, RCX
    CALL GetModuleHandleA
    MOV  QWORD[HINSTANCE], RAX ; Save hInstance

    ; Create The Icon
    MOV  RCX,             RAX               ; HINSTANCE
    MOV  RDX,             16                ; WIDTH
    MOV  R8,              16                ; HEIGHT
    MOV  R9,              1                 ; # of XOR planes 
    MOV  QWORD[rsp + 32], 1                 ; # bits per pixel 
    MOV  QWORD[rsp + 40], ICON_AND_BIT_MASK ; AND bitmask 
    MOV  QWORD[rsp + 48], ICON_XOR_BIT_MASK ; XOR bitmask
    CALL CreateIcon
    MOV  QWORD[HICON], RAX ; Save the HICON

    ; Create WNDCLASSA
    MOV  DWORD[rsp + 32],      3               ; style
    MOV  QWORD[rsp + 32 + 8],  _window_proc    ; lpfnWndProc
    MOV  DWORD[rsp + 32 + 16], 0               ; cbClsExtra
    MOV  DWORD[rsp + 32 + 20], 0               ; cbWndExtra
    MOV  RAX, QWORD[HINSTANCE]
    MOV  QWORD[rsp + 32 + 24], RAX             ; hInstance
    MOV  RAX, QWORD[HICON]
    MOV  QWORD[rsp + 32 + 32], RAX             ; hIcon
    XOR  RCX, RCX       ; HINSTANCE=NULL
    MOV  RDX, IDC_CROSS ; TODO:
    CALL LoadCursorA
    MOV  QWORD[rsp + 32 + 40], RAX             ; hCursor
    MOV  QWORD[rsp + 32 + 48], 0               ; hbrBackground
    MOV  QWORD[rsp + 32 + 56], 0               ; lpszMenuName
    MOV  QWORD[rsp + 32 + 64], WindowClassName ; lpszClassName

    ; Register The Window Class
    LEA  RCX, [RSP + 32] ; WNDCLASSA*
    CALL RegisterClassA

    ; Get The Desired Window's Rect From The Client's Rect
    ; #1 : Create The RECT
    MOV  DWORD[RSP+32],    0        ; coud be simplified to MOV QWORD..., 0
    MOV  DWORD[RSP+32+4],  0        ; 
    MOV  DWORD[RSP+32+8],  WIDTH
    MOV  DWORD[RSP+32+12], HEIGHT

    ; #2 : Obtain The RECT
    LEA  RCX, [RSP+32]    ; 
    MOV  RDX, CUSTOM_WINDOW_DW_STYLE ; DWORD dwStyle
    XOR  R8,  R8          ; BOOL  bMenu
    CALL AdjustWindowRect

    ; #3 : Extract The Required Client Area Dimensions
    MOV  R11D, DWORD[RSP+32]     ; WindowRECT.LEFT
    MOV  R10D, DWORD[RSP+32+8]   ; WindowRECT.RIGHT
    SUB  R10D, R11D              ; Actual Window Width

    MOV  R12D, DWORD[RSP+32+4]   ; WindowRECT.TOP
    MOV  R11D, DWORD[RSP+32+12]  ; WindowRECT.BOTTOM
    SUB  R11D, R12D              ; Actual Window HEIGHT

    ; Create The Window
    XOR  RCX, RCX             ; dwExStyle
    MOV  RDX, WindowClassName ; lpClassName
    MOV  R8,  WindowName      ; lpWindowName
    MOV  R9,  CUSTOM_WINDOW_DW_STYLE        ; dwStyle

    MOV  QWORD[RSP + 20h + 56], 0          ; lpParam
    MOV  RAX, QWORD[HINSTANCE]             ; 
    MOV  QWORD[RSP + 20h + 48], RAX        ; hInstance
    MOV  QWORD[RSP + 20h + 40], 0          ; hMenu
    MOV  QWORD[RSP + 20h + 32], 0          ; hWndParent
    MOV  DWORD[RSP + 20h + 24], R11D       ; nHeight
    MOV  DWORD[RSP + 20h + 16], R10D       ; nWidth
    MOV  QWORD[RSP + 20h + 8],  0x80000000 ; Y
    MOV  QWORD[RSP + 20h],      0x80000000 ; X

    CALL CreateWindowExA
    MOV  QWORD[HWND], RAX ; Save the window handle

    ; Show The Window
    MOV  RCX, QWORD[HWND]
    MOV  RDX, 5
    CALL ShowWindow

    ADD  RSP, 112

_start_init_game:
    SUB  RSP, 32
    ; Allocate the snake
    XOR  RCX, RCX                     ; uFlags:  GMEM_FIXED
    MOV  RDX, SNAKE_BUFFER_SIZE       ; dwBytes: SNAKE_BUFFER_SIZE
    CALL GlobalAlloc                  ;
    MOV  QWORD[SNAKE_BUFFER_PTR], RAX ; Save the buffer pointer

    ADD  RSP, 32

    ; Set the Head
    MOV  DWORD[RAX],   (GRID_SQUARE_SIDE_LENGTH*5)
    MOV  DWORD[RAX+4], (GRID_SQUARE_SIDE_LENGTH*5)

    MOV  DWORD[RAX+4+4],   (GRID_SQUARE_SIDE_LENGTH*4)
    MOV  DWORD[RAX+4+4+4], (GRID_SQUARE_SIDE_LENGTH*5)

    ; Set Timer For Next Update/Draw
    MOV RCX, QWORD[HWND]         ; HNWD
    MOV RDX, 1                   ; Timer ID 1 (Update/Draw Timer ID)
    MOV R8,  FRAME_TIME          ;
    MOV R9,  _update_render_game ;
    call SetTimer

_start_program_loop:
_start_program_loop_message_loop:
    SUB  RSP, 40

    LEA  RCX, [MSG]
    XOR  RDX, RDX  ; Null handle to get WM_QUIT message
    XOR  R8,  R8   ;
    XOR  R9,  R9   ;
    MOV  DWORD[RSP + 20h], 1
    CALL PeekMessageA

    ADD  RSP, 40

    CMP  RAX, 0                          ; Check if there are no more messages in the queue
    JE   _start_program_loop_next

    CMP  DWORD[MSG+8], 12h  ; Compare MSG.message and WM_QUIT
    JE   _start_epilogue

    SUB  RSP, 32

    LEA  RCX, [MSG]
    CALL TranslateMessage

    LEA  RCX, [MSG]
    CALL DispatchMessageA

    ADD  RSP, 32

_start_program_loop_next:
    JMP  _start_program_loop

_start_game_over:
_start_epilogue:
    ; Free Snake Buffer Memory
    MOV  RCX, QWORD[SNAKE_BUFFER_PTR]
    CALL GlobalFree

    ; Destroy The Icon
    MOV  RCX, QWORD[HICON]
    CALL DestroyIcon

    ; Usual Epilogue
    MOV	 RSP, RBP
    POP	 RBP

    ; Exit Process
    XOR  RCX, RCX
    SUB  RSP, 32
    CALL ExitProcess
    ADD  RSP, 32

    ; Return Value
    XOR  RAX, RAX
    RET




_window_proc:
    PUSH RBP
    MOV  RBP, RSP

    CMP  RDX, 0x10           ; WM_CLOSE
    JE   window_proc_close
    CMP  RDX, 0x2            ; WM_DESTROY
    JE   window_proc_destroy
    CMP  RDX, 0x100          ; WM_KEYDOWN
    JE   window_proc_keydown
    CMP  RDX, 0xF            ; WM_PAINT
    jne  window_proc_default

_window_proc_paint:
    SUB RSP, 136; 20h+72+8
        ; PAINTSTRUCT  72
        ; Ssample Rect 32 
        ; Shadow Space 32

_window_proc_paint_begin:
    LEA  RDX, [RSP+64] ; 
    CALL BeginPaint    ; 
    MOV  RBX, RAX      ; save hdc

_window_proc_paint_draw_backgroud:
    ; Create Background Color Brush
    MOV  RCX, BACKGROUND_BRUSH_COLOR
    CALL CreateSolidBrush

    ; Draw Background
    MOV  RCX, RBX      ; hdc
    LEA  RDX, [RSP+76] ; *lprc: PAINTSTRUCT.rcPaint
    MOV  R8,  RAX      ;  hbr
    CALL FillRect      ;

    MOV RCX, R8
    CALL DeleteObject

_window_proc_paint_draw_apple:
    ; Create Apple Color Brush
    MOV  RCX, APPLE_BRUSH_COLOR
    CALL CreateSolidBrush

    ; Create Apple Struct: TODO:: OPTIMIZE GETTING FULL QWORD FROM APPLE (X;Y)
    MOV R12D,          DWORD[APPLE]   ; APPLE.X
    MOV DWORD[rsp+32], R12D           ; RECT.Left
    
    MOV R13D,          DWORD[APPLE+4] ; APPLE.Y
    MOV DWORD[rsp+36], R13D           ; RECT.Top

    ADD R12D,          GRID_SQUARE_SIDE_LENGTH
    MOV DWORD[rsp+40], R12D           ; Rect.Right
    
    ADD R13D,          GRID_SQUARE_SIDE_LENGTH
    MOV DWORD[rsp+44], R13D           ; Rect.Bottom

    ; Draw Apple
    MOV  RCX, RBX      ; hdc
    LEA  RDX, [RSP+32] ; *lprc: PAINTSTRUCT.rcPaint
    MOV  R8,  RAX      ; hbr
    CALL FillRect      ;

    MOV RCX, R8
    CALL DeleteObject

_window_proc_paint_draw_snake:
    ; Get Snake Color Brush
    MOV  RCX, SNAKE_BRUSH_COLOR
    CALL CreateSolidBrush
    MOV  R14, RAX          ; brush

    MOV RSI, QWORD[SNAKE_BUFFER_PTR]
    MOV R12, QWORD[SNAKE_LEN]
    SHL R12, 1
    XOR R13, R13

_window_proc_paint_draw_snake_loop:
    SHL R13, 2 ; Some magic to account for dwords by multiplying by 4 the offset

    ; Create Snake Body Rect
    MOV R15D, DWORD[RSI+R13]
    MOV DWORD[rsp+32], R15D ; Left
    ADD R15D, GRID_SQUARE_SIDE_LENGTH
    MOV DWORD[rsp+40], R15D ; Right

    MOV R15D, DWORD[RSI+R13+4]
    MOV DWORD[rsp+36], R15D ; Top
    ADD R15D, GRID_SQUARE_SIDE_LENGTH
    MOV DWORD[rsp+44], R15D ; Bottom

    SHR R13, 2 ; Undo the magic

    ; Draw Snake Body
    MOV  RCX, RBX      ; hdc
    LEA  RDX, [RSP+32] ; *lprc: PAINTSTRUCT.rcPaint
    MOV  R8,  R14      ;  hbr
    CALL FillRect      ;

    ; Loop Stuff
    ADD R13, 2
    CMP R13, R12
    JNE _window_proc_paint_draw_snake_loop

_window_proc_paint_draw_snake_loop_end:
    MOV  RCX, R14
    CALL DeleteObject

_window_proc_paint_check_border_intersection: ; I don't like the fact that I need to do this check in WM_PAINT but I can't do anything about it
    MOV R15, QWORD[SNAKE_BUFFER_PTR]

    ; Check X Border Intersection
    MOV R12D, DWORD[R15]
    CMP R12D, 0
    JL  _start_game_over
    CMP R12D, WIDTH-GRID_SQUARE_SIDE_LENGTH
    JGE _start_game_over

    ; Check Y Border Intersection
    MOV R13D, DWORD[R15+4]
    CMP R13D, 0
    JL  _start_game_over
    CMP R13D, HEIGHT-GRID_SQUARE_SIDE_LENGTH
    JGE _start_game_over

_window_proc_paint_check_snake_self_intersection:
    ; Loop through each snake body part and see if it is at another's location by looping again through each snake body part

    MOV R14, QWORD[SNAKE_LEN]
    SHL R14, 3 ; Snake Buffer Size = SNAKE_LEN * 8 = SNAKE_LEN << 3
    MOV R10, 0 ; Offset 1
    
    _window_proc_paint_check_snake_self_intersection_loop_1:
        MOV R11, 0 ; Offset 2

        _window_proc_paint_check_snake_self_intersection_loop_2:
            
            ; Check If They Are Same Body Part (really the same, same index)
            CMP R10, R11
            JE  _window_proc_paint_check_snake_self_intersection_loop_2_next_it

            ; Check If They are at the same location
            ; Load Each Position As A QWORD (2 DWORDS)
            MOV RAX, QWORD[R15+R10-8] ; Position 1
            MOV RDI, QWORD[R15+R11-8] ; Position 2
            CMP RAX, RDI
            JE  _start_game_over
            
            _window_proc_paint_check_snake_self_intersection_loop_2_next_it:
                ADD R11, 8
                CMP R11, R14
                JNE _window_proc_paint_check_snake_self_intersection_loop_2

        ADD R10, 8
        CMP R10, R14
        JNE _window_proc_paint_check_snake_self_intersection_loop_1

_window_proc_paint_end:
    MOV  RCX, QWORD[HWND]
    LEA  RDX, [RSP+40]
    CALL EndPaint

    ADD  RSP, 136

    XOR  RAX, RAX
    JMP  window_proc_epilogue

window_proc_close:
    SUB  RSP, 20h
    CALL DestroyWindow
    ADD  RSP, 20h

    XOR  RAX, RAX
    JMP  window_proc_epilogue

window_proc_destroy:
    SUB  RSP, 20h
    XOR  RCX, RCX
    CALL PostQuitMessage
    ADD  RSP, 20h

    XOR  RAX, RAX
    JMP  window_proc_epilogue

window_proc_keydown:
    XOR  RAX, RAX ; Set return value

    ; Test KeyCodes: Keycode in R8 (wParam)
    CMP  R8, 0x25 ; Left
    JE   window_proc_keydown_handle_key_left_arrow
    CMP  R8, 0x27 ; Right
    JE   window_proc_keydown_handle_key_right_arrow
    CMP  R8, 0x26 ; Up
    JE   window_proc_keydown_handle_key_up_arrow
    CMP  R8, 0x28 ; Down
    JE   window_proc_keydown_handle_key_down_arrow
    JMP  window_proc_keydown_epilogue

window_proc_keydown_handle_key_left_arrow:
    MOV  DWORD[SNAKE_DIR],   -GRID_SQUARE_SIDE_LENGTH
    MOV  DWORD[SNAKE_DIR+4], 0

    JMP  window_proc_keydown_epilogue

window_proc_keydown_handle_key_right_arrow:
    MOV  DWORD[SNAKE_DIR],   GRID_SQUARE_SIDE_LENGTH
    MOV  DWORD[SNAKE_DIR+4], 0

    JMP  window_proc_keydown_epilogue

window_proc_keydown_handle_key_up_arrow:
    MOV  DWORD[SNAKE_DIR],   0
    MOV  DWORD[SNAKE_DIR+4], -GRID_SQUARE_SIDE_LENGTH

    JMP  window_proc_keydown_epilogue

window_proc_keydown_handle_key_down_arrow:
    MOV  DWORD[SNAKE_DIR],   0
    MOV  DWORD[SNAKE_DIR+4], GRID_SQUARE_SIDE_LENGTH

    JMP  window_proc_keydown_epilogue

window_proc_keydown_epilogue:
    XOR  RAX, RAX
    JMP  window_proc_epilogue

window_proc_default:
    SUB  RSP, 20h
    CALL DefWindowProcA
    ADD  RSP, 20h

window_proc_epilogue:
    MOV  RSP, RBP
    POP  RBP
    RET

    section .data

WindowClassName db 'Snake x64-64 Class', 0 ; A null-terminated string containing The window class's name
WindowName      db 'Snake x86-64',       0 ; A null-terminated string containing the name of the window
SNAKE_DIR       dd GRID_SQUARE_SIDE_LENGTH,       0 ; Snake Movement Delta (X,Y)
SNAKE_LEN       dq 2                       ; (head + tail at the beginning)

APPLE           dd GRID_SQUARE_SIDE_LENGTH*10, GRID_SQUARE_SIDE_LENGTH*20 ; Apple Position (X,Y)

; Custom Icon Image Data
; Reference on the meaning of these custom values https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-createicon.
ICON_AND_BIT_MASK db 252,0,252,0,252,127,252,127,252,127,252,127,252,127,252,127,252,127,252,127,252,127,252,127,252,127,0,127,0,127,0,127
ICON_XOR_BIT_MASK dq 0,0,0,0

    section .bss

HINSTANCE        resb 8  ; A WIN32 'HINSTANCE' (handle) to current instance/module (here .exe file)
HICON            resb 8  ; A WIN32 'HICON' (handle) to an icon (here the window's icon)
HWND             resb 8  ; A WIN32 'HWND'  (handle) to a window
MSG              resb 48 ; A WIN32 'MSG'  struct containing a window message
SNAKE_BUFFER_PTR resb 8  ; A pointer to the snake's dynamically allocated buffer containg the positions of his body parts