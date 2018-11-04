.386

.model flat,stdcall
option casemap:none
.stack 4096

;     include files
include windows.inc
include masm32.inc
include gdi32.inc
include user32.inc
include kernel32.inc
include Comctl32.inc
include comdlg32.inc
include shell32.inc
include oleaut32.inc
include msvcrt.inc
include winmm.inc
include shfolder.inc
include dnslib.inc
;include C:\masm32\macros\macros.asm

;     libraries
includelib masm32.lib
includelib gdi32.lib
includelib user32.lib
includelib kernel32.lib
includelib Comctl32.lib
includelib comdlg32.lib
includelib shell32.lib
includelib oleaut32.lib
includelib msvcrt.lib
includelib winmm.lib

WinMain proto:DWORD, :DWORD, :DWORD, :DWORD
InitInstance proto:HINSTANCE,:DWORD
Play proto: LPVOID



.data
FileInfo struct
	filename WCHAR 256 DUP(?)
	filesize LARGE_INTEGER <>
FileInfo ends

Files FileInfo 1024 DUP(<>)

;typedef enum PlayOperation
NONEPLAY equ 0
STOPPLAY equ 1
RESUMEPLAY equ 2
PAUSEPLAY equ 3
STARTPLAY equ 4
;typedef enum PlayOperation

;typedef enum PlayStatus
STOPSTATUS equ 0
PLAYSTATUS equ 1
PAUSESTATUS equ 2
;typedef enum PlayStatus

Status struct
	filename WCHAR 256 DUP(?)
	wIdDevice MCIDEVICEID ?
	playStatus dword ?
	operation dword ?
	pos dword ?
	len dword ?
Status ends

status Status <>

cmd WCHAR 300 DUP(?)


szWindowClass db "MusicPlayer",0
szTitle db "MusicPlayer",0
AppName db "MusicPlayer", 0
szTextFileName db "FileName",0
szTextFileSize db "FileSize",0

fontname db 'Consolas', 0
text_button db "button", 0
text_play db "Play", 0
text_stop db "Stop", 0
text_pause db "Pause", 0
text_resume db "Resume", 0
text_repeat db "单曲循环", 0
text_edit db "edit",0
text_opendir db "Open Directory", 0
text_browse_folder db "Browse folder", 0
text_listbox db "listbox", 0


find_dir_fmt db '%', 0, 's', 0, '\', 0, '*',0, 0, 0; "%s\\*"
handle_play_fmt db 'C', 0, 'o', 0, 'u', 0, 'n', 0, 't', 0, '=', 0, '%', 0, 'd', 0, ' ', 0, 'M', 0, 'a', 0, 'r', 0, 'k', 0, '=', 0, '%', 0, 'd', 0, 0, 0;"Count=%d Mark=%d"
s_fmt db '%',0,'s',0, 0, 0 ;"%s"
d_fmt db '%', 0, 'd', 0, 0, 0
noneplay_fmt db '%', 0, '.', 0, '2', 0, 'd', 0, ':', 0, '%', 0, '.', 0, '2', 0, 'd', 0, 0, 0 ;"%.2d:%.2d"
startplay_fmt db '%', 0, 's', 0, '\', 0, '%', 0, 's', 0, 0, 0 ;"%s\\%s"
;stopplay_fmt db '0', 0, '0', 0, ':', 0, '0', 0, '0', 0, 0, 0;"00:00"
stopplay_fmt db '00:00', 0;"00:00"
PROGRESSCLASS db "msctls_progress32",0
LISTVIEWCLASS db "SysListView32",0
music_file_error db "Open Music File Error!",0dh,0ah 
                 db "Please Check the Media file!", 0dh,0ah 
				 db  "Or Your Audio decoder can not decode the file!", 0

text_static db "static",0
text_0000 db "00:00",0

; 控件的全局ID
IDC_PLAYBTN HMENU 205
IDC_LISTVIEW HMENU 206
IDC_OPENDIRBTN HMENU 207
IDC_EDIT HMENU 208
IDC_CURRENTPLAYTIME HMENU 209
IDC_TOTALPLAYTIME HMENU 210
IDC_STOPBTN HMENU 211
IDC_PROGRESSBAR HMENU 212
IDC_LIST HMENU 213
IDC_REPEATE HMENU 214

.data?
hInstance HINSTANCE ?
CommandLine LPSTR ? 

; 控件的Handle
hFont HFONT ?
hPlayBtn HWND ?
hwndPB HWND ?
hListView HWND ?
hOpenDirBtn HWND ?
hwndEdit HWND ?
hStopBtn HWND ?
hTotalPlayTime HWND ?
hCurrentPlayTime HWND ?
hList HWND ?
hRepeatBtn HWND ?

; 当前目录
DIR WCHAR 1024 DUP(0)
; 提示信息
Info WCHAR 2048 DUP(?)


.code
start:
	invoke GetModuleHandle, NULL
	mov hInstance, eax
	invoke GetCommandLine
	mov CommandLine, eax
	invoke WinMain, hInstance, NULL, CommandLine, SW_SHOWDEFAULT
	invoke ExitProcess, eax

;----------------------------------
;注册窗口类
;
MyRegisterClass proc hInst:HINSTANCE
;----------------------------------
	LOCAL wcex: WNDCLASSEXW
	mov wcex.cbSize, sizeof WNDCLASSEX
	mov wcex.style, CS_HREDRAW or CS_VREDRAW
	mov wcex.lpfnWndProc, OFFSET WndProc 
	mov wcex.cbClsExtra, NULL
	mov wcex.cbWndExtra, NULL
	push hInst
	pop wcex.hInstance
	mov wcex.hbrBackground, COLOR_WINDOW + 1
	mov wcex.lpszMenuName, NULL
	mov wcex.lpszClassName ,offset szWindowClass
	invoke LoadIcon, NULL, IDI_APPLICATION
	mov wcex.hIcon, eax
	mov wcex.hIconSm, eax
	invoke LoadCursor, NULL, IDC_ARROW
	mov wcex.hCursor, eax
	invoke RegisterClassEx, addr wcex
	ret
MyRegisterClass endp

WinMain proc hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine: LPSTR, CmdShow:DWORD
	local msg :MSG


	invoke MyRegisterClass, hInst
	invoke InitInstance, hInst, CmdShow

	; 主消息循环
	.while TRUE
		invoke GetMessage, addr msg, NULL, 0, 0
		.break .if (!eax)
		invoke TranslateMessage, addr msg
		invoke DispatchMessage, addr msg
	.endw

	mov eax, msg.wParam
	ret

WinMain endp

;---------------------
;函数: InitInstance(HINSTANCE, int)
;目标: 保存实例句柄并创建主窗口
;注释:
;
;        在此函数中，我们在全局变量中保存实例句柄并
;        创建和显示主程序窗口。
InitInstance proc hInst: HINSTANCE, CmdShow :DWORD
;------------------------
	local hwnd:HWND
	invoke CreateWindowEx, NULL, addr szWindowClass, addr szTitle, 
		WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 500, 600, 
		NULL, NULL, hInst, NULL
	mov hwnd, eax

	.if (!eax)
		ret
	.endif
	
	invoke ShowWindow, hwnd, SW_SHOWNORMAL
	invoke UpdateWindow, hwnd

	ret
InitInstance endp 

;-----------------------------------------
; 创建控件
;
CreateWindowControl proc uses eax hWnd:HWND
;------------------------------------------
	local lvc:LVCOLUMN
	; 创建字体
	invoke CreateFont, -15 , -8, 0, 0, 400,
		FALSE, FALSE, FALSE, DEFAULT_CHARSET,
		OUT_CHARACTER_PRECIS,CLIP_CHARACTER_PRECIS,
		DEFAULT_QUALITY,FF_DONTCARE,
		offset fontname
	mov hFont, eax

	;创建play按钮
	invoke CreateWindowEx, 0, offset text_button, offset text_play, 
		WS_VISIBLE or WS_CHILD or BS_PUSHBUTTON,
		0, 0, 0, 0,
		hWnd, IDC_PLAYBTN, hInstance, NULL
	mov hPlayBtn, eax

	invoke SendMessage, hPlayBtn, WM_SETFONT, hFont, NULL

	;创建stop按钮
	invoke CreateWindowEx, 0, offset text_button, offset text_stop, 
		WS_VISIBLE or WS_CHILD or BS_PUSHBUTTON,
		0, 0, 0, 0,
		hWnd, IDC_STOPBTN, hInstance, NULL
	mov hStopBtn, eax

	invoke SendMessage, hStopBtn, WM_SETFONT, hFont, NULL

	;创建repeat复选框
	invoke CreateWindowEx, 0, offset text_button, offset text_repeat, 
		WS_VISIBLE or WS_CHILD or BS_AUTOCHECKBOX or BS_LEFT,
		0, 0, 0, 0,
		hWnd, IDC_REPEATE, hInstance, NULL
	mov hRepeatBtn, eax

	invoke SendMessage, hRepeatBtn, WM_SETFONT, hFont, NULL

	; 创建进度条
	invoke CreateWindowEx, 0, offset PROGRESSCLASS, NULL ,
		WS_VISIBLE or WS_CHILD or PBS_SMOOTH,
		0, 0, 0, 0,
		hWnd,
		IDC_PROGRESSBAR,
		hInstance,
		NULL
	mov hwndPB, eax

	;创建listview
	;invoke CreateWindowEx, 0, offset LISTVIEWCLASS, NULL ,
	;	WS_VISIBLE or WS_CHILD or LVS_REPORT or LVS_EDITLABELS,
	;	0, 0, 0, 0,
	;	hWnd,
	;	IDC_LISTVIEW,
	;	hInstance,
	;	NULL
	;mov hListView, eax
	;mov lvc.mask,  01111b
	;mov lvc._mask, 1111b
	;mov lvc.iSubItem, 0
	;mov lvc.pszText, offset szTextFileName
	;mov lvc._cx, 350

	;invoke SendMessage, hListView, LVM_INSERTCOLUMN, 0, addr lvc
	;mov lvc.iSubItem, 1 
	;mov lvc.pszText, offset szTextFileSize
	;mov lvc._cx, 100
	;invoke SendMessage, hListView, LVM_INSERTCOLUMN, 1, addr lvc
	
	;创建ListBox
	invoke CreateWindowEx, 0, offset text_listbox, NULL ,
		WS_VISIBLE or WS_CHILD or LBS_STANDARD,
		0, 0, 0, 0,
		hWnd,
		IDC_LIST,
		hInstance,
		NULL
	mov hList, eax
	invoke SendMessage, hList, WM_SETFONT, hFont, NULL


	;创建打开文件按钮
	invoke CreateWindowEx, 0, offset text_button, offset text_opendir, 
		WS_VISIBLE or WS_CHILD or BS_PUSHBUTTON,
		0, 0, 0, 0,
		hWnd, IDC_OPENDIRBTN, hInstance, NULL
	mov hOpenDirBtn, eax
	invoke SendMessage, hOpenDirBtn, WM_SETFONT, hFont, NULL



	; 创建编辑框
	invoke CreateWindowEx, 0, offset text_edit, NULL,
		WS_CHILD or WS_VISIBLE or ES_LEFT or ES_MULTILINE or \
		ES_AUTOVSCROLL or ES_READONLY,
		0, 0, 0, 0, 
		hWnd,IDC_EDIT,hInstance, NULL
	mov hwndEdit, eax
	invoke SendMessage, hwndEdit, WM_SETFONT, hFont, NULL

	; 创建播放时间文本框

	invoke CreateWindowEx, 0, offset text_static, offset text_0000,
		WS_CHILD or WS_VISIBLE or SS_RIGHT,
		0, 0, 0, 0,
		hWnd, IDC_CURRENTPLAYTIME, hInstance, NULL
	mov hCurrentPlayTime, eax
	invoke SendMessage, hCurrentPlayTime, WM_SETFONT, hFont, NULL

	invoke CreateWindowEx, 0, offset text_static, offset text_0000,
		WS_CHILD or WS_VISIBLE or SS_LEFT,
		0, 0, 0, 0,
		hWnd, IDC_TOTALPLAYTIME, hInstance, NULL
	mov hTotalPlayTime, eax
	invoke SendMessage, hTotalPlayTime, WM_SETFONT, hFont, NULL




	ret
CreateWindowControl endp

;-----------------------------------------
; 调整控件位置
;
ReSizeWindowControl proc uses eax ebx hWnd:HWND
;-----------------------------------------
	local rc:RECT
	local current_width:DWORD
	local current_height:DWORD
	local middle:DWORD
	local playBtn_bottom:DWORD

	local pb_left:DWORD
	local pb_bottom:DWORD
	local pb_width:DWORD

	local lv_left:DWORD
	local lv_top:DWORD
	local lv_width:DWORD
	local lv_height:DWORD

	local pl_time_left:DWORD

	local edit_top:DWORD

	; 确定 play 按钮的位置
	mov eax, 0 
	invoke GetClientRect, hWnd, addr rc
	mov ebx, rc.right
	sub ebx, rc.left
	mov current_width, ebx ; current_width =  rc.right - rc.left
	mov eax, current_width
	mov ebx, 2
	mov edx, 0
	div ebx
	mov middle, eax ;middle = current_width /2
	sub middle, 30

	mov ebx, rc.bottom
	sub ebx, rc.top
	mov current_height, ebx
	mov eax, rc.bottom
	mov playBtn_bottom, eax
	sub playBtn_bottom, 40


	invoke MoveWindow, hPlayBtn, middle, playBtn_bottom, 60, 30, TRUE

	; 确定 stop 按钮的位置
	mov eax, 0 
	invoke GetClientRect, hWnd, addr rc
	mov ebx, rc.right
	sub ebx, rc.left
	mov current_width, ebx ; current_width =  rc.right - rc.left
	mov eax, current_width
	mov ebx, 2
	mov dx, 0
	div ebx
	mov middle, eax ;middle = current_width /2
	sub middle, 95

	mov ebx, rc.bottom
	sub ebx, rc.top
	mov current_height, ebx
	mov eax, rc.bottom
	mov playBtn_bottom, eax
	sub playBtn_bottom, 40


	invoke MoveWindow, hStopBtn, middle, playBtn_bottom, 60, 30, TRUE

	; 确定 repeat 按钮的位置
	mov eax, 0 
	invoke GetClientRect, hWnd, addr rc
	mov ebx, rc.right
	sub ebx, rc.left
	mov current_width, ebx ; current_width =  rc.right - rc.left
	mov eax, current_width
	mov ebx, 2
	mov dx, 0
	div ebx
	mov middle, eax ;middle = current_width /2
	add middle, 80

	mov ebx, rc.bottom
	sub ebx, rc.top
	mov current_height, ebx
	mov eax, rc.bottom
	mov playBtn_bottom, eax
	sub playBtn_bottom, 40


	invoke MoveWindow, hRepeatBtn, middle, playBtn_bottom, 90, 30, TRUE

	; 确定进度条的位置
	mov eax, rc.left
	add eax, 80
	mov pb_left, eax
	mov eax, rc.bottom
	sub eax, 70
	mov pb_bottom,eax
	mov eax, current_width
	sub eax, 160
	mov pb_width, eax

	invoke MoveWindow, hwndPB, pb_left, pb_bottom, pb_width, 15, TRUE

	;确定ListBox 的位置
	mov eax, rc.left
	add eax, 20
	mov lv_left, eax
	mov eax, rc.top
	add eax, 10
	mov lv_top, eax
	mov eax, current_width
	sub eax, 40
	mov lv_width, eax
	mov eax, current_height
	sub eax, 250
	mov lv_height, eax

	invoke MoveWindow, hList, lv_left, lv_top, lv_width, lv_height, TRUE

	; 确定打开文件夹按钮位置

	invoke MoveWindow, hOpenDirBtn, lv_left, playBtn_bottom, 120, 30, TRUE

	; 确定播放时间显示位置

	invoke MoveWindow, hCurrentPlayTime, lv_left, pb_bottom, 55, 15, TRUE

	mov eax, rc.right
	sub eax, 75
	mov pl_time_left, eax
	invoke MoveWindow, hTotalPlayTime, pl_time_left, pb_bottom, 55, 15, TRUE


	mov eax, rc.bottom
	sub eax, 200
	mov edit_top, eax
	invoke MoveWindow, hwndEdit, lv_left, edit_top, lv_width, 60, TRUE

	ret
ReSizeWindowControl endp

;------------------------------
; 选择目录
;
SelectDir proc hWnd:HWND
	local bInfo: BROWSEINFO
	local lpDlist: DWORD
	invoke RtlZeroMemory, addr bInfo, sizeof BROWSEINFO ;一定要把内存清0，否则会报错
	invoke GetForegroundWindow
	mov bInfo.hwndOwner, eax
	mov bInfo.lpszTitle, offset text_browse_folder
	mov bInfo.ulFlags, BIF_RETURNONLYFSDIRS or BIF_USENEWUI or BIF_UAHINT or BIF_NONEWFOLDERBUTTON ;/*不带新建文件夹按钮*/
	invoke SHBrowseForFolder, addr bInfo
	mov lpDlist, eax

	cmp eax, 0 ; if lpDlist != NULL
	;jnz returnselectdir
	invoke SHGetPathFromIDListW ,lpDlist, offset DIR
	;mov ecx, offset DIR
returnselectdir:	
	ret 40
SelectDir endp



handlePlay proc uses eax ebx ecx, hWnd:HWND 
	;local count: dword
	;local mark: dword
	local index:dword
	local ThreadID: dword
	local handle: HANDLE
	;invoke SendMessage, hListView, LVM_GETSELECTEDCOUNT, 0, 0
	;mov count, eax
	;invoke SendMessage, hListView, LVM_GETSELECTIONMARK, 0, 0
	;mov mark, eax

	invoke SendMessage, hList, LB_GETCURSEL, 0, 0
	mov index, eax

	;invoke wsprintfW, addr Info, offset handle_play_fmt, count, mark
	;invoke SendMessageW, hwndEdit, WM_SETTEXT, 0, addr Info

	.if index != LB_ERR
		.if status.playStatus == STOPSTATUS
			mov ebx, offset Files
			mov eax, sizeof FileInfo
			mul index
			add ebx, eax
			assume ebx:PTR FileInfo

			mov status.operation, STARTPLAY
			invoke wsprintfW, addr status.filename, offset s_fmt ,addr [ebx].filename
			;invoke wcscpy, offset status.filename, [ebx].filename
			invoke CreateThread, NULL, 0, Play, NULL, 0, addr ThreadID
			mov handle, eax
			assume ebx:nothing
		.endif
	.endif

	.if status.playStatus == PLAYSTATUS
		mov status.operation, PAUSEPLAY
	.elseif status.playStatus == PAUSESTATUS
		mov status.operation, RESUMEPLAY
	.endif

	ret
handlePlay endp

Play proc uses eax ebx edx, lpParam: LPVOID
	local return:dword
	local mop:MCI_OPEN_PARMSW
	local mpp:MCI_PLAY_PARMS
	local msp:MCI_STATUS_PARMS
	local currentTime[30]: WCHAR
	local totalTime[30]: WCHAR


	invoke RtlZeroMemory, addr mop, sizeof MCI_OPEN_PARMSW ;
	invoke RtlZeroMemory, addr mpp, sizeof MCI_PLAY_PARMS ;
	invoke RtlZeroMemory, addr msp, sizeof MCI_STATUS_PARMS ;

L_while:
	.if status.operation == NONEPLAY
		mov msp.dwItem, MCI_STATUS_POSITION
		invoke mciSendCommandW, mop.wDeviceID, MCI_STATUS, MCI_STATUS_ITEM, addr msp
		mov eax, msp.dwReturn
		mov status.pos, eax
		mov ebx, 100
		mov edx, 0
		div ebx
		invoke SendMessage, hwndPB, PBM_SETPOS, eax, 0
		mov eax, status.pos
		mov ebx, 1000
		mov edx, 0
		div ebx
		mov edx, 0
		mov ebx, 60
		div ebx
		invoke wsprintfW, addr currentTime, offset noneplay_fmt, eax, edx
		invoke SetWindowTextW, hCurrentPlayTime, addr currentTime

		mov eax, status.len
		.if status.pos == eax
			mov eax, STOPPLAY
			mov status.operation, eax
		.endif

	.elseif status.operation == STARTPLAY
		mov status.operation, NONEPLAY
		invoke wsprintfW, addr cmd, offset startplay_fmt, offset DIR, addr status.filename
		invoke SendMessageW, hwndEdit, WM_SETTEXT, 0, addr cmd
		mov mop.lpstrElementName, offset cmd
		invoke mciSendCommandW, NULL, MCI_OPEN, MCI_OPEN_ELEMENT, addr mop
		mov return, eax
		.if return != 0
			invoke SendMessage, hwndEdit, WM_SETTEXT, 0, offset music_file_error
			ret
		.endif

		mov mpp.dwFrom, 0
		mov mpp.dwCallback, NULL
		invoke mciSendCommandW, mop.wDeviceID, MCI_PLAY, MCI_NOTIFY, addr mpp
		mov msp.dwItem, MCI_STATUS_LENGTH
		invoke mciSendCommandW, mop.wDeviceID, MCI_STATUS, MCI_STATUS_ITEM, addr msp
		mov eax, msp.dwReturn
		mov status.len, eax

		;((LONG)(((WORD)(((DWORD_PTR)(a)) & 0xffff)) | ((DWORD)((WORD)(((DWORD_PTR)(b)) & 0xffff))) << 16))
		;SendMessage(hwndPB, PBM_SETRANGE, 0, MAKELPARAM(0, status.length / 100))
		mov eax, status.len
		mov ebx, 100
		mov edx, 0
		div ebx
		and eax, 1111111111111111b
		shl eax, 16
		mov ebx, eax

		mov eax, 0
		and eax, 1111111111111111b

		or eax, ebx
		invoke SendMessage, hwndPB, PBM_SETRANGE, 0, eax

		mov eax, status.len
		mov ebx, 1000
		mov edx, 0
		div ebx
		mov ebx, 60
		mov edx, 0
		div ebx
		invoke wsprintfW, addr totalTime, offset noneplay_fmt, eax, edx
		invoke SetWindowTextW, hTotalPlayTime, addr totalTime
		mov status.playStatus, PLAYSTATUS
		invoke SetWindowText, hPlayBtn, offset text_pause

	.elseif status.operation == PAUSEPLAY
		mov status.operation, NONEPLAY
		mov status.playStatus, PAUSESTATUS
		invoke SetWindowText, hPlayBtn, offset text_resume
		invoke mciSendCommandW, mop.wDeviceID, MCI_PAUSE, 0, addr mpp
	
	.elseif status.operation == STOPPLAY
		invoke mciSendCommandW, mop.wDeviceID, MCI_STOP, 0, addr mpp
		invoke mciSendCommandW, mop.wDeviceID, MCI_CLOSE, NULL, NULL
		mov status.playStatus, STOPSTATUS
		mov status.operation, NONEPLAY
		invoke SetWindowText, hTotalPlayTime, offset stopplay_fmt
		invoke SetWindowText, hCurrentPlayTime, offset stopplay_fmt
		invoke SetWindowText, hPlayBtn, offset text_play
		invoke SendMessage, hwndPB, PBM_SETPOS, 0, 0
		invoke SendMessage, hRepeatBtn, BM_GETCHECK, 0, 0
		.if eax == BST_CHECKED
			invoke handlePlay, NULL
		.endif
		ret
	.elseif status.operation == RESUMEPLAY
		mov status.operation, NONEPLAY
		mov status.playStatus, PLAYSTATUS
		invoke SetWindowText, hPlayBtn, offset text_pause
		invoke mciSendCommandW, mop.wDeviceID, MCI_RESUME, 0, addr mpp
	.endif

	invoke Sleep, 100
	jmp L_while

	ret
Play endp



FindFile proc
	local ffd: WIN32_FIND_DATA
	local hFind: HANDLE
	local FileCount: DWORD
	;local lvI:LVITEMW
	local tempdir[260]:WCHAR

	;invoke RtlZeroMemory, addr lvI, sizeof LVITEMW
	invoke RtlZeroMemory,addr ffd,sizeof WIN32_FIND_DATA
	invoke RtlZeroMemory, addr tempdir, sizeof tempdir
	;mov lvI.pszText, LPSTR_TEXTCALLBACKW
	;mov lvI._mask, LVIF_TEXT or LVIF_IMAGE or LVIF_STATE
	invoke wsprintfW, addr tempdir, offset find_dir_fmt, offset DIR
	invoke FindFirstFileW, addr tempdir, addr ffd
	mov hFind, eax

	.if hFind == -1
		ret ; error!
	.endif
	mov FileCount, 0

	invoke SendMessageW, hwndEdit, WM_SETTEXT, 0, addr tempdir
	invoke SendMessage, hList, LB_RESETCONTENT, 0, 0

	do_start:
		mov eax, ffd.dwFileAttributes
		and eax, FILE_ATTRIBUTE_DIRECTORY
		cmp eax, 0
		jnz do; if it is directory, jump to label 'do'

		
		mov eax, FileCount
		mov ebx, sizeof FileInfo
		mul ebx
		assume ebx:PTR FileInfo
		mov ebx, offset Files
		add ebx, eax
		invoke wsprintfW, addr [ebx].filename, offset s_fmt, addr ffd.cFileName
		invoke SendMessageW, hList, LB_INSERTSTRING, FileCount, addr ffd.cFileName

		mov eax, ffd.nFileSizeHigh
		mov [ebx].filesize.HighPart, eax
		mov eax, ffd.nFileSizeLow
		mov [ebx].filesize.LowPart, eax
		assume ebx:nothing
		inc FileCount
	do:
		invoke FindNextFileW, hFind, addr ffd
		cmp eax, 0
		jnz do_start


	ret
FindFile endp




WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM 
	local ps:PAINTSTRUCT 
	local wmId:WORD
	.if uMsg == WM_DESTROY
		invoke PostQuitMessage,NULL 

	.elseif uMsg == WM_COMMAND
		mov eax, DWORD PTR [wParam]
		and eax, 0ffffh
		; mov wmId, ax
		.if eax == IDC_OPENDIRBTN
			invoke SelectDir, hWnd
			invoke FindFile
		.elseif eax == IDC_PLAYBTN
			invoke handlePlay, hWnd
		.elseif eax == IDC_STOPBTN
			invoke SendMessage, hRepeatBtn, BM_GETCHECK, 0, 0
			.if eax == BST_CHECKED
				invoke SendMessage, hRepeatBtn, BM_SETCHECK, 0, 0
			.endif
			mov status.operation, STOPPLAY
		.endif

	.elseif uMsg == WM_PAINT
		invoke BeginPaint, hWnd, ADDR ps 
		invoke EndPaint, hWnd, ADDR ps 
	.elseif uMsg == WM_NOTIFY

	; 创建控件
	.elseif uMsg == WM_CREATE
		invoke InitCommonControls
		invoke CreateWindowControl, hWnd
	
	; 窗口变化大小
	.elseif uMsg == WM_SIZE
		invoke ReSizeWindowControl, hWnd
	.else
		invoke DefWindowProc, hWnd, uMsg, wParam, lParam 
	.endif
	ret
WndProc endp

end start

