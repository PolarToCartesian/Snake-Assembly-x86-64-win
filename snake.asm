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
%define GRID_SQUARE_SIDE_COUNT  64 ; # squares (Must be a power of two) (In order to make generating random apple positions simpler.
%define FRAME_TIME              75 ; the delta-time in ms between each frame/update.

; Auto-Gnerated Constants
%define WIDTH             (GRID_SQUARE_SIDE_LENGTH*GRID_SQUARE_SIDE_COUNT) ; The width  in pixels of the window's client area
%define HEIGHT            (WIDTH)                                          ; The height in pixels of the window's client area
%define PIXEL_COUNT       (WIDTH*HEIGHT)
%define SNAKE_BUFFER_SIZE (PIXEL_COUNT * 8)                                ; The size of the buffer containg the snake's body positions' locations (X: DWORD, Y: DWORD)

; Useful Constants For x86-64 Assembly
%define SHADOW_SPACE_SIZE (20h)        ; 20h=0x20=32 (bytes of shadow space).
%define WORD_SIZE         (2)          ; # bytes
%define DWORD_SIZE        (4)          ; # bytes
%define QWORD_SIZE        (8)          ; # bytes
%define POINTER_SIZE      (QWORD_SIZE) ; # bytes

; WIN32 Constants
%define IDC_CROSS      (32515)

%define WS_OVERLAPPED  (0x00000000)
%define WS_CAPTION     (0x00C00000)
%define WS_SYSMENU     (0x00080000)
%define WS_MINIMIZEBOX (0x00020000)
%define WS_MAXIMIZEBOX (0x00010000)

%define CW_USEDEFAULT  (0x80000000)

%define SW_SHOW (0x5)

%define WM_CLOSE   (0x0010)
%define WM_DESTROY (0x0002)
%define WM_KEYDOWN (0x0100)
%define WM_PAINT   (0x000F)

%define VK_LEFT  (0x25)
%define VK_RIGHT (0x27)
%define VK_UP    (0x26)
%define VK_DOWN  (0x28)

%define RDW_INVALIDATE (0x1)

; WIN32 x64 type sizes
%define HWND_SIZE        (QWORD_SIZE)   ; # bytes
%define PAINTSTRUCT_SIZE (72)           ; # bytes
%define RECT_SIZE        (4*DWORD_SIZE) ; # bytes
%define HANDLE_SIZE      (POINTER_SIZE) ; # bytes

; WIN32 Combined Flags
%define CUSTOM_WINDOW_DW_STYLE (WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX)

; WIN32 Brush 0x00BBGGRR Colors
%define SNAKE_BRUSH_COLOR      (0x0000FF00)
%define APPLE_BRUSH_COLOR      (0x000000FF)
%define BACKGROUND_BRUSH_COLOR (0x00000000)




    section .text




; <<< Start of function _apple_new_position >>>

; Changes The Apple's Position
; C-style syntax: void _apple_new_position(void)
_apple_new_position: ;TODO: Random Position
    MOV ECX, GRID_SQUARE_SIDE_LENGTH  ; Used in the MUL instructions later

    ; Generate Random X Position
    RDRAND EAX                        ; EAX=Random 32 bit value
    AND EAX, GRID_SQUARE_SIDE_COUNT-1 ; EAX=Random Grid Square Index because GRID_SQUARE_SIDE_COUNT is a power of 2
    MUL ECX                           ; Multiply by grid square side length to get X position

    MOV  DWORD[APPLE],   EAX

    ; Generate Random Y Position
    RDRAND EAX
    AND EAX, 63
    AND EAX, GRID_SQUARE_SIDE_COUNT-1
    MUL ECX

    MOV  DWORD[APPLE+4], EAX

    RET

; <<< End of function _apple_new_position >>>


; <<< Start of function move_snake_and_render >>>
; Renders the game and moves the snake (w/o checking for intersections)
; C-style syntax: void move_snake_and_render(void)
move_snake_and_render:
move_snake_and_render___update:
    MOV R15, QWORD[SNAKE_BUFFER_PTR]

    ; Move the rest of the body starting from the part just after the head
    MOV R9, QWORD[SNAKE_LEN]
    SHL R9, 3 ; Multiply by 8 (2 dwords): current offset

move_snake_and_render___move_body_loop: ; Probably doesn't work for a snake size > 2
    ; Update X
    MOV R10D, DWORD[R15+R9-8]
    MOV DWORD[R15+R9], R10D

    ; Update Y
    MOV R10D, DWORD[R15+R9-4]
    MOV DWORD[R15+R9+4], R10D

    ; Handle Loop
    SUB R9, 8
    CMP R9, 8
    JGE move_snake_and_render___move_body_loop

move_snake_and_render___move_head:
    ; Move Head X
    MOV R12D, DWORD[R15]
    ADD R12D, DWORD[SNAKE_DIR] 
    MOV DWORD[R15], R12D

    ; Move Head Y
    MOV R13D, DWORD[R15+4]
    ADD R13D, DWORD[SNAKE_DIR+4] 
    MOV DWORD[R15+4], R13D

move_snake_and_render___repaint:
    SUB  RSP, SHADOW_SPACE_SIZE

    MOV  RCX, QWORD[HWND]
    XOR  RDX, RDX
    XOR  R8,  R8
    MOV  R9,  RDW_INVALIDATE
    CALL RedrawWindow

    ADD  RSP, SHADOW_SPACE_SIZE

move_snake_and_render___apple_collision:
    ; Check If Head Intersects The Apple
    CMP R12D, DWORD[APPLE]
    JNE move_snake_and_render___return
    CMP R13D, DWORD[APPLE+4]
    JNE move_snake_and_render___return

    ; Increment the snake length
    MOV RAX, QWORD[SNAKE_LEN]
    INC RAX
    MOV QWORD[SNAKE_LEN], RAX

    CMP R12D, DWORD[APPLE]
    JNE move_snake_and_render___return
    CMP R13D, DWORD[APPLE+4]
    JNE move_snake_and_render___return

    call _apple_new_position

move_snake_and_render___return:
    RET

; <<< End of function move_snake_and_render >>>


; <<< Start of function _start >>>
; The application's entry point
; C-style syntax: void _start(void)
_start:
    ; Prologue
    PUSH RBP
    MOV  RBP, RSP

    SUB  RSP, 112 ; MEMORY used for RECT & WNDCLASSA + SHADOW

    ; Obtain the module's instance handle
    XOR  RCX, RCX               ; Param #1: LPCSTR lpModuleName = NULL
    CALL GetModuleHandleA       ; Call the win32 function GetModuleHandleA
    MOV  QWORD[HINSTANCE], RAX  ; Save the module's HINSTANCE

    ; Create the window's icon
    MOV  RCX,                                           RAX               ; Param #1: HINSTANCE
    MOV  RDX,                                           16                ; Param #2: WIDTH  in # of pixels
    MOV  R8,                                            16                ; Param #3: HEIGHT in # of pixels
    MOV  R9,                                            1                 ; Param #4: # of XOR  planes 
    MOV  QWORD[rsp + SHADOW_SPACE_SIZE + 0*QWORD_SIZE], 1                 ; Param #5: # of bits per pixel 
    MOV  QWORD[rsp + SHADOW_SPACE_SIZE + 1*QWORD_SIZE], ICON_AND_BIT_MASK ; Param #6: AND bitmask*
    MOV  QWORD[rsp + SHADOW_SPACE_SIZE + 2*QWORD_SIZE], ICON_XOR_BIT_MASK ; Param #7: XOR bitmask*
    CALL CreateIcon                                                       ; call win32 function CreateIcon
    MOV  QWORD[HICON], RAX                                                ; Save the HICON

    ; Create the WNDCLASSA structure needed to create the window
    MOV  DWORD[rsp + SHADOW_SPACE_SIZE],                               3               ; WNDCLASSA.style
    MOV  QWORD[rsp + SHADOW_SPACE_SIZE + 1*QWORD_SIZE],                _window_proc    ; WNDCLASSA.lpfnWndProc
    MOV  DWORD[rsp + SHADOW_SPACE_SIZE + 2*QWORD_SIZE],                0               ; WNDCLASSA.cbClsExtra
    MOV  DWORD[rsp + SHADOW_SPACE_SIZE + 2*QWORD_SIZE + 1*DWORD_SIZE], 0               ; WNDCLASSA.cbWndExtra
    MOV  RAX, QWORD[HINSTANCE]
    MOV  QWORD[rsp + SHADOW_SPACE_SIZE + 3*QWORD_SIZE],                RAX             ; WNDCLASSA.hInstance
    MOV  RAX, QWORD[HICON]
    MOV  QWORD[rsp + SHADOW_SPACE_SIZE + 4*QWORD_SIZE],                RAX             ; WNDCLASSA.hIcon

    XOR  RCX, RCX       ; Parameter #1: HINSTANCE hInstance    = NULL
    MOV  RDX, IDC_CROSS ; Parameter #2: LPCSTR    lpCursorName = IDC_CROSS
    CALL LoadCursorA    ; Call the win32 function LoadCursorA to get a handle to the desired cursor

    MOV  QWORD[rsp + SHADOW_SPACE_SIZE + 5*QWORD_SIZE],                RAX             ; WNDCLASSA.hCursor
    MOV  QWORD[rsp + SHADOW_SPACE_SIZE + 6*QWORD_SIZE],                0               ; WNDCLASSA.hbrBackground
    MOV  QWORD[rsp + SHADOW_SPACE_SIZE + 7*QWORD_SIZE],                0               ; WNDCLASSA.lpszMenuName
    MOV  QWORD[rsp + SHADOW_SPACE_SIZE + 8*QWORD_SIZE],                WindowClassName ; WNDCLASSA.lpszClassName

    ; Register The Window Class
    LEA  RCX, [RSP + SHADOW_SPACE_SIZE] ; Parameter #1: WNDCLASSA* lpWndClass
    CALL RegisterClassA                 ; Call the win32 function RegisterClassA to register the window class that we just defined

    ; Get The Desired Window's Rect From The Client's Rect
    ; #1 : Create The RECT structre of the desired client area
    MOV  DWORD[RSP + SHADOW_SPACE_SIZE + 0*DWORD_SIZE], 0      ; RECT.left   (CLIENT) in # of pixels
    MOV  DWORD[RSP + SHADOW_SPACE_SIZE + 1*DWORD_SIZE], 0      ; RECT.top    (CLIENT) in # of pixels
    MOV  DWORD[RSP + SHADOW_SPACE_SIZE + 2*DWORD_SIZE], WIDTH  ; RECT.right  (CLIENT) in # of pixels
    MOV  DWORD[RSP + SHADOW_SPACE_SIZE + 3*DWORD_SIZE], HEIGHT ; RECT.bottom (CLIENT) in # of pixels

    ; #2 : Obtain the RECT corresponding the window's actual size
    LEA  RCX, [RSP + SHADOW_SPACE_SIZE] ; Parameter #1: RECT* lpRect  (CLIENT)
    MOV  RDX, CUSTOM_WINDOW_DW_STYLE    ; Parameter #2: DWORD dwStyle
    XOR  R8,  R8                        ; Parameter #3: BOOL  bMenu
    CALL AdjustWindowRect               ; Call the win32 function AdjustWindowRect. The desired rect replaces the rect we supplied.

    ; #3 : Extract the required window's dimensions
    MOV  R11D, DWORD[RSP + SHADOW_SPACE_SIZE]                ; RECT.LEFT  (WINDOW)
    MOV  R10D, DWORD[RSP + SHADOW_SPACE_SIZE + 2*DWORD_SIZE] ; RECT.RIGHT (WINDOW)
    SUB  R10D, R11D                                          ; Actual Window Width

    MOV  R12D, DWORD[RSP + SHADOW_SPACE_SIZE + 1*DWORD_SIZE] ; WindowRECT.TOP
    MOV  R11D, DWORD[RSP + SHADOW_SPACE_SIZE + 3*DWORD_SIZE] ; WindowRECT.BOTTOM
    SUB  R11D, R12D                                          ; Actual Window Height

    ; Create the window
    XOR  RCX, RCX                                                     ; Parameter #1:  dwExStyle
    MOV  RDX, WindowClassName                                         ; Parameter #2:  lpClassName
    MOV  R8,  WindowName                                              ; Parameter #3:  lpWindowName
    MOV  R9,  CUSTOM_WINDOW_DW_STYLE                                  ; Parameter #4:  dwStyle
    MOV  QWORD[RSP + SHADOW_SPACE_SIZE + 0*QWORD_SIZE], CW_USEDEFAULT ; Parameter #5:  window x position in # of pixels
    MOV  QWORD[RSP + SHADOW_SPACE_SIZE + 1*QWORD_SIZE], CW_USEDEFAULT ; Parameter #6:  window y position in # of pixels
    MOV  DWORD[RSP + SHADOW_SPACE_SIZE + 2*QWORD_SIZE], R10D          ; Parameter #7:  window width  in # of pixels
    MOV  DWORD[RSP + SHADOW_SPACE_SIZE + 3*QWORD_SIZE], R11D          ; Parameter #8:  window height in # of pixels
    MOV  QWORD[RSP + SHADOW_SPACE_SIZE + 4*QWORD_SIZE], 0             ; Parameter #9:  hWndParent
    MOV  QWORD[RSP + SHADOW_SPACE_SIZE + 5*QWORD_SIZE], 0             ; Parameter #10: hMenu
    MOV  RAX, QWORD[HINSTANCE]                                        ;
    MOV  QWORD[RSP + SHADOW_SPACE_SIZE + 6*QWORD_SIZE], RAX           ; Parameter #11: hInstance
    MOV  QWORD[RSP + SHADOW_SPACE_SIZE + 7*QWORD_SIZE], 0             ; Parameter #12: lpParam
    CALL CreateWindowExA                                              ; Call the win32 function CreateWindowExA
    
    MOV  QWORD[HWND], RAX ; Save the window handle

    ; Show the window to the user
    MOV  RCX, QWORD[HWND] ; Parameter #1: HWND hWnd     : handle to the window
    MOV  RDX, SW_SHOW     ; Parameter #2: int  nCmdShow : flag
    CALL ShowWindow       ; Call the win32 function ShowWindow

    ADD  RSP, 112 ; Free the used stack spaced

_start_init_game:
    SUB  RSP, SHADOW_SPACE_SIZE
    ; Allocate the snake
    XOR  RCX, RCX                     ; uFlags:  GMEM_FIXED
    MOV  RDX, SNAKE_BUFFER_SIZE       ; dwBytes: SNAKE_BUFFER_SIZE
    CALL GlobalAlloc                  ;
    MOV  QWORD[SNAKE_BUFFER_PTR], RAX ; Save the buffer pointer

    ADD  RSP, SHADOW_SPACE_SIZE

    ; Set the Head
    MOV  DWORD[RAX],   (GRID_SQUARE_SIDE_LENGTH*5)
    MOV  DWORD[RAX+4], (GRID_SQUARE_SIDE_LENGTH*5)

    MOV  DWORD[RAX+4+4],   (GRID_SQUARE_SIDE_LENGTH*4)
    MOV  DWORD[RAX+4+4+4], (GRID_SQUARE_SIDE_LENGTH*5)

    ; Set Timer For Next Update/Draw
    MOV RCX, QWORD[HWND]         ; HNWD
    MOV RDX, 1                   ; Timer ID 1 (Update/Draw Timer ID)
    MOV R8,  FRAME_TIME          ;
    MOV R9,  move_snake_and_render ;
    call SetTimer

_start_program_loop:
_start_program_loop_message_loop:
    SUB  RSP, 40

    LEA  RCX, [MSG]
    XOR  RDX, RDX  ; Null handle to get WM_QUIT message
    XOR  R8,  R8   ;
    XOR  R9,  R9   ;
    MOV  DWORD[RSP + SHADOW_SPACE_SIZE], 1
    CALL PeekMessageA

    ADD  RSP, 40

    CMP  RAX, 0                          ; Check if there are no more messages in the queue
    JE   _start_program_loop_next

    CMP  DWORD[MSG+8], 12h  ; Compare MSG.message and WM_QUIT
    JE   _start_epilogue

    SUB  RSP, SHADOW_SPACE_SIZE

    LEA  RCX, [MSG]
    CALL TranslateMessage

    LEA  RCX, [MSG]
    CALL DispatchMessageA

    ADD  RSP, SHADOW_SPACE_SIZE

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
    SUB  RSP, SHADOW_SPACE_SIZE
    CALL ExitProcess
    ADD  RSP, SHADOW_SPACE_SIZE

    ; Return Value
    XOR  RAX, RAX
    RET


; <<< End of function _start >>>


; <<< Start of function _window_proc >>>
; The WIN32 WindowProc callback function which receives and treats window events
; C-style syntax: u64 _window_proc(HWND hwnd, u32 uMsg, u64 wParam, u64 lParam);
_window_proc:
    PUSH RBP
    MOV  RBP, RSP

    CMP  RDX, WM_CLOSE
    JE   _window_proc_close
    CMP  RDX, WM_DESTROY
    JE   _window_proc_destroy
    CMP  RDX, WM_KEYDOWN
    JE   _window_proc_keydown
    CMP  RDX, WM_PAINT
    jne  _window_proc_default

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
    MOV DWORD[rsp+SHADOW_SPACE_SIZE], R12D           ; RECT.Left
    
    MOV R13D,          DWORD[APPLE+4] ; APPLE.Y
    MOV DWORD[rsp+SHADOW_SPACE_SIZE+4], R13D           ; RECT.Top

    ADD R12D,          GRID_SQUARE_SIDE_LENGTH
    MOV DWORD[rsp+SHADOW_SPACE_SIZE+4+4], R12D           ; Rect.Right
    
    ADD R13D,          GRID_SQUARE_SIDE_LENGTH
    MOV DWORD[rsp+SHADOW_SPACE_SIZE+4+4+4], R13D           ; Rect.Bottom

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
    MOV DWORD[rsp+SHADOW_SPACE_SIZE], R15D ; Left
    ADD R15D, GRID_SQUARE_SIDE_LENGTH
    MOV DWORD[rsp+SHADOW_SPACE_SIZE+4+4], R15D ; Right

    MOV R15D, DWORD[RSI+R13+4]
    MOV DWORD[rsp+SHADOW_SPACE_SIZE+4], R15D ; Top
    ADD R15D, GRID_SQUARE_SIDE_LENGTH
    MOV DWORD[rsp+SHADOW_SPACE_SIZE+4+4+4], R15D ; Bottom

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
    JMP  _window_proc_epilogue

_window_proc_close:
    SUB  RSP, SHADOW_SPACE_SIZE
    CALL DestroyWindow
    ADD  RSP, SHADOW_SPACE_SIZE

    XOR  RAX, RAX
    JMP  _window_proc_epilogue

_window_proc_destroy:
    SUB  RSP, SHADOW_SPACE_SIZE
    XOR  RCX, RCX
    CALL PostQuitMessage
    ADD  RSP, SHADOW_SPACE_SIZE

    XOR  RAX, RAX
    JMP  _window_proc_epilogue

_window_proc_keydown:
    XOR  RAX, RAX ; Set return value

    ; Test KeyCodes: Keycode in R8 (wParam)
    CMP  R8, VK_LEFT
    JE   _window_proc_keydown_handle_key_left_arrow
    CMP  R8, VK_RIGHT
    JE   _window_proc_keydown_handle_key_right_arrow
    CMP  R8, VK_UP
    JE   _window_proc_keydown_handle_key_up_arrow
    CMP  R8, VK_DOWN
    JE   _window_proc_keydown_handle_key_down_arrow
    JMP  _window_proc_keydown_epilogue

_window_proc_keydown_handle_key_left_arrow:
    MOV  DWORD[SNAKE_DIR],   -GRID_SQUARE_SIDE_LENGTH
    MOV  DWORD[SNAKE_DIR+4], 0

    JMP  _window_proc_keydown_epilogue

_window_proc_keydown_handle_key_right_arrow:
    MOV  DWORD[SNAKE_DIR],   GRID_SQUARE_SIDE_LENGTH
    MOV  DWORD[SNAKE_DIR+4], 0

    JMP  _window_proc_keydown_epilogue

_window_proc_keydown_handle_key_up_arrow:
    MOV  DWORD[SNAKE_DIR],   0
    MOV  DWORD[SNAKE_DIR+4], -GRID_SQUARE_SIDE_LENGTH

    JMP  _window_proc_keydown_epilogue

_window_proc_keydown_handle_key_down_arrow:
    MOV  DWORD[SNAKE_DIR],   0
    MOV  DWORD[SNAKE_DIR+4], GRID_SQUARE_SIDE_LENGTH

    JMP  _window_proc_keydown_epilogue

_window_proc_keydown_epilogue:
    XOR  RAX, RAX
    JMP  _window_proc_epilogue

_window_proc_default:
    SUB  RSP, SHADOW_SPACE_SIZE
    CALL DefWindowProcA
    ADD  RSP, SHADOW_SPACE_SIZE

_window_proc_epilogue:
    MOV  RSP, RBP
    POP  RBP
    RET

; <<< End of function _window_proc >>>




    section .data




WindowClassName db 'Snake x64-64 Class', 0 ; A null-terminated string containing The window class's name
WindowName      db 'Snake x86-64',       0 ; A null-terminated string containing the name of the window
SNAKE_DIR       dd GRID_SQUARE_SIDE_LENGTH,       0 ; Snake Movement Delta (X,Y)
SNAKE_LEN       dq 2                       ; (head + tail at the beginning)

APPLE           dd GRID_SQUARE_SIDE_LENGTH*10, GRID_SQUARE_SIDE_LENGTH*20 ; Apple Position (X,Y)

; Custom Icon Image Data
; Reference on the meaning of these custom values https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-createicon.
; I had to write a Python script to generate these values from an iamge I created.
ICON_AND_BIT_MASK db 252,0,252,0,252,127,252,127,252,127,252,127,252,127,252,127,252,127,252,127,252,127,252,127,252,127,0,127,0,127,0,127
ICON_XOR_BIT_MASK dq 0,0,0,0




    section .bss




HINSTANCE        resb HANDLE_SIZE  ; A WIN32 'HINSTANCE' (handle) to current instance/module (here .exe file)
HICON            resb HANDLE_SIZE  ; A WIN32 'HICON' (handle) to an icon (here the window's icon)
HWND             resb HANDLE_SIZE  ; A WIN32 'HWND'  (handle) to a window
MSG              resb 48           ; A WIN32 'MSG'  struct containing a window message
SNAKE_BUFFER_PTR resb POINTER_SIZE ; A pointer to the snake's dynamically allocated buffer containg the positions of his body parts