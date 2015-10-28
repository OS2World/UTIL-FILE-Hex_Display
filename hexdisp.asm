			PAGE	80,132
			TITLE	OS/2 hex browse program
			.286c
			.xlist
			include sysmac.inc
			.list

		extrn	DosRead:far

@BTHS		MACRO	FROM,TO,LEN
		push	cx
		push	es
		push	di
		push	ds
		push	si
		mov	cx,seg FROM
		push	cx
		pop	ds
		mov	si,offset FROM
		mov	cx,seg TO
		push	cx
		pop	es
		mov	di,offset TO
		mov	cx,LEN
		call	os2bths
		pop	si
		pop	ds
		pop	di
		pop	es
		pop	cx
		ENDM
@BTH		MACRO	FROM,TO
		push	ax
		push	es
		push	di
		mov	di,offset TO
		mov	ax,seg TO
		push	ax
		pop	es
		mov	ax,FROM
		call	os2bth
		pop	di
		pop	es
		pop	ax
		ENDM

		
@BTA		MACRO	FROM,TO,LEN
		push	cx
		push	es
		push	di
		push	ax
		IFIDN	< ES:DI >,< TO >
		ELSE
		IFIDN	< DS:SI >,< TO >
		push	ds
		pop	es
		mov	di,si
		ELSE
		IFIDN	< SS:BP >,< TO >
		push	ss
		pop	es
		mov	di,si
		ELSE
		mov	ax,seg TO
		push	ax
		pop	es
		mov	di,offset TO
		ENDIF
		ENDIF
		ENDIF
		mov	ax,FROM
		mov	cx,LEN
		call	os2bta
		pop	ax
		pop	di
		pop	es
		pop	cx
		ENDM

@JAXZ		MACRO	TARGET
		or	ax,ax
		jnz	$+5
		jmp	TARGET
		nop
		ENDM

@JAXNZ		MACRO	TARGET
		or	ax,ax
		jz	$+5
		jmp	TARGET
		nop
		ENDM

@GETPARMS	MACRO	TO,LEN
		push	es
		push	di
		push	cx
		mov	cx,seg TO
		push	cx
		pop	es
		mov	cx,LEN
		mov	di,offset TO
		call	os2parms
		pop	cx
		pop	di
		pop	es
		ENDM

charbuf		struc
charascii	db	?
charscan	db	?
charstat	db	?
charDBCSs	db	?
charshift	dw	?
chartimehi	dw	?
chartimelo	dw	?
charbuf		ends

dgroup	group	HEX_data

HEX_stack	segment para stack

		dw	256 dup('s')

HEX_stack	ends

HEX_DATA	segment para public 'auto'

dline		db	'    '
dofsh		db	'HHHH'
dofsl		db	'HHHH    '
dhex1		db	'HHHHHHHH '
dhex2		db	'HHHHHHHH    '
dhex3		db	'HHHHHHHH '
dhex4		db	'HHHHHHHH     *'
ddata		db	'dddddddddddddddd*'
		db	5 dup(' ')

topmsg		db	'HEXDISP: '
topfn		db	33 dup (' ')
		db	'<PgUp> <PgDn> <ESC> Page '
topcur		db	'xxxx of '
toptot		db	'xxxx '

msg1		db	'You must enter a file name',0ah,0dh
MSG1L		equ	$ - offset msg1

msg2		db	'Open error on file name : '
MSG2L		equ	$ - offset msg2

keydata		charbuf	<>
XX		equ	01bh
UP		equ	4900h
AUP		equ	49e0h
DN		equ	5100h
ADN		equ	51e0h
STDERR		equ	2

hexsegsz	dw	0
hexsegp		dw	0
hexseg		dw	0
hexofs		dw	0
hexlaspar	dw	0
hexlasbyt	dw	0
shift		dw	0

green		db	2fh
fill		db	' ',1fh
bytesin		dw	0
bytesout	dw	0
temp		dw	0

fname		db	64 dup(0)
fnamel		dw	0
fhand		dw	0
fact		dw	0
fsize		dd	0
fattr		dw	0
fflag		dw	00000001b
fmode		dw	0000000000100000b
frsv		dd	0
fofsl		dw	0
fofsh		dw	0
nofs		dd	0

HEX_data	ends

HEX_code	segment para public 'code'
		assume cs:HEX_code,ds:nothing,es:HEX_data,ss:Hex_stack

main		proc
		push	ds
		pop	es

		call	openf
		@jaxnz	hex999
		call	getfile
		@jaxnz	hex999
		call	showfile

hex999:		@DosExit 1,0
main		endp

openf		proc
		@getparms	fname,63
		@jaxnz	opf010
		@DosWrite	stderr,msg1,MSG1L,bytesout
		mov	ax,0ffh
		jmp	opf999

opf010:		mov	cx,ax
		mov	di,offset fname
		mov 	al,' '
		repne	scasb
		jcxz	opf020
		dec	di
opf020:		mov	byte ptr [di],0
		sub	di,offset fname
		mov	fnamel,di
		@DosOpen fname,fhand,fact,fsize,fattr,fflag,fmode,frsv
		@jaxz	opf999
		@DosWrite stderr,msg2,msg2l,bytesout
		@DosWrite stderr,fname,63,bytesout
		mov	ax,0ffh
opf999:		ret
openf		endp

getfile		proc
		mov	fofsl,0
		@DosChgFilePtr fhand,fofsl,2,fofsl
		mov	word ptr nofs,0
		@DosChgFilePtr fhand,nofs,0,nofs

get010:		mov	dx,fofsl
		add	dx,16
		mov	hexsegsz,dx
		@DosAllocHuge fofsh,dx,hexsegp,0,0
		cmp	ax,0
		je	get015
		mov	ax,0ffh
		jmp	get999

get015:		push	hexsegp
		pop	ds
		@DosGetHugeShift shift
		mov	di,1
		mov	cx,shift
		shl	di,cl
		mov	shift,di
		push	ds
		xor	si,si
		mov	cx,fofsh
		jcxz	get030

get020:		push	fhand
		push	ds
		push	si
		push	-1
		push	ds
		push	bytesin
		call	DosRead
		push	cx
		mov	ax,ds
		add	ax,shift
		mov	ds,ax
		pop	cx
		loop	get020

get030:		push	fhand
		push	ds
		push	si
		push	hexsegsz
		push	ds
		push	bytesin
		call	DosRead
		@DosClose fhand
		xor	ax,ax
		pop	ds

get999:		ret
getfile		endp

showfile	proc

		push	ds
		push	es
		pop	ds
		lea	si,fname
		lea	di,topfn
		mov	cx,fnamel
		cmp	cx,33
		jle	shf010
		mov	cx,33
shf010:		rep	movsb
		pop	ds
		mov	dx,fofsh
		mov	ax,fofsl
		mov	bx,16*24
		div	bx
		mov	temp,ax
		@bta	temp,toptot,4
		@VioScrollUp 0,0,-1,-1,-1,fill,0
		@VioWrtCharStrAtt topmsg,80,0,0,green,0
		mov	hexofs,0
		mov	hexseg,0
		mov	dx,fofsh
		mov	bx,fofsl
		call	showscreen

shf020:		@KbdCharIn keydata,0,0
		cmp	keydata.charascii,XX
		jne	shf030
		jmp	shf999
shf030:		cmp	word ptr keydata.charascii,UP
		je	shf032
		cmp	word ptr keydata.charascii,AUP
		jne	shf040
shf032:		cmp	hexofs,0
		jne	shf035
		cmp	hexseg,0
		jne	shf035
		@DosBeep 1000,200
		jmp	shf020
shf035:		mov	di,hexofs
		sub	hexofs,16*24
		cmp	hexofs,di
		jb	shf037
		mov	ax,ds
		sub	ax,shift
		mov	ds,ax
		dec	hexseg
shf037:		push	hexseg
		push	ds
		call	showscreen
		pop	ds
		pop	hexseg
		jmp	shf020
shf040:		cmp	word ptr keydata.charascii,DN
		je	shf042
		cmp	word ptr keydata.charascii,ADN
		jne	shf050
shf042:		add	hexofs,16*24
shf043:		cmp	dx,hexseg
		jne	shf045
		cmp	bx,hexofs
		jae	shf045
		@DosBeep 1000,200
		sub	hexofs,16*24
		jmp	shf020
shf045:		call	showscreen
		jmp	shf020
shf050:		jmp	shf020
shf999:		ret
showfile	endp

showscreen	proc
		push	hexofs
		push	dx
		push	bx
		mov	dx,hexseg
		mov	ax,hexofs
		mov	bx,16*24
		div	bx
		mov	temp,ax
		@bta	temp,topcur,4
		@VioWrtCharStrAtt topmsg,80,0,0,green,0
		pop	bx
		pop	dx
		mov	cx,24
		mov	si,1
shs010:		call	formatline
		@VioWrtCharStr dline,80,si,1,0
		add	hexofs,16
		cmp	hexofs,0
		jne	shs020
		mov	ax,ds
		add	ax,shift
		mov	ds,ax
		inc	hexseg
shs020:		inc	si
		loop	shs010
		pop	hexofs
		ret
showscreen	endp

formatline	proc
		push	cx
		push	si
		cmp	dx,hexseg
		jne	fmt010
		cmp	bx,hexofs
		jae	fmt010
		mov	cx,40
		mov	ax,'  '
		lea	di,dline
		rep	stosw
		jmp	fmt999
fmt010:		mov	cx,16
		mov	si,hexofs
		lea	di,ddata-1
		mov	al,'*'
		stosb
		rep	movsb
		stosb
		@bth	hexofs,dofsl,4
		@bth	hexseg,dofsh,4
		@bths	ddata+00,dhex1,4
		@bths	ddata+04,dhex2,4
		@bths	ddata+08,dhex3,4
		@bths	ddata+12,dhex4,4
fmt999:		pop	si
		pop	cx
		ret
formatline	endp

os2parms	proc
public		os2parms

		push	si
		push	ds
		push	cx
		push	di
		push	es
		push	ax
		mov	cx,64
		mov	es,ax
		mov	di,bx
		mov	ax,0
		repne	scasb
		mov	ax,' '
		repe	scasb
		dec	di
		pop	ds
		pop	es
		mov	si,di
		pop	di
		pop	cx
		xor	ax,ax
par010:		cmp	byte ptr [si],0
		je	par999
		movsb
		inc	ax
		loop	par010

par999:		pop	ds
		pop	si
		ret
os2parms	endp
os2bta		proc
public		os2bta
WBLEN		equ	5
		push	bp
		sub	sp,WBLEN
		mov	bp,sp
		push	ax
		push	bx
		push	cx
		push	di
		push	dx
		xor	dx,dx
		push	cx
		push	di
		push	ax
		mov	al,' '
		rep	stosb
		pop	ax
		pop	di
		pop	cx
		push	cx
		mov	cx,WBLEN
		mov	bx,10000
		push	bp
bta010:		div	bx
		aam
		or	ax,'00'
		mov	ss:[bp],al
		inc	bp
		push	dx
		mov	ax,bx
		xor	dx,dx
		mov	bx,10
		div	bx
		mov	bx,ax
		pop	ax
		loop	bta010
		pop	bp
		mov	cx,WBLEN-1
bta015:		cmp	byte ptr ss:[bp],'0'
		jne	bta020
		mov	byte ptr ss:[bp],' '
		inc	bp
		loop	bta015
bta020:		mov	ax,cx
		pop	cx
		cmp	ax,cx
		jl	bta030
		mov	al,'*'
		rep	stosb
		jmp	bta999
bta030:		inc	ax
		add	di,cx
		sub	di,ax
		mov	cx,ax
bta035:		mov	al,ss:[bp]
		stosb
		inc	bp
		loop	bta035
bta999:		pop	dx
		pop	di
		pop	cx
		pop	bx
		pop	ax
		add	sp,WBLEN
		pop	bp
		ret
os2bta		endp
os2bths		proc
public		os2bths
		push	bx
		push	ax
		xor	ax,ax
		mov	bx,offset hextab
bhs010:		lodsb
		push	cx
		push	ax
		and	al,0f0h
		mov	cl,4
		shr	al,cl
		push	bx
		add	bx,ax
		mov	al,byte ptr cs:[bx]
		pop	bx
		stosb
		pop	ax
		and	al,0fh
		push	bx
		add	bx,ax
		mov	al,byte ptr cs:[bx]
		pop	bx
		stosb
		pop	cx
		loop	bhs010
bhs999:		pop	ax
		pop	bx
		ret
hextab		db	'0123456789ABCDEF'
os2bths		endp

os2bth		proc
public		os2bth
		push	bx
		push	cx
		push	si
		mov	si,offset hextab
		push	ax
		and	ax,0f000h
		mov 	cl,12
		shr	ax,cl
		mov	bx,ax
		mov	al,byte ptr cs:[bx+si]
		stosb
		pop	ax
		push	ax
		and	ax,0f00h
		mov	cl,8
		shr	ax,cl
		mov	bx,ax
		mov	al,byte ptr cs:[bx+si]
		stosb
		pop	ax
		push	ax	
		and	ax,0f0h
		mov	cl,4
		shr	ax,cl
		mov	bx,ax
		mov	al,byte ptr cs:[bx+si]
		stosb
		pop	ax
		and	ax,0fh
		mov	bx,ax
		mov	al,byte ptr cs:[bx+si]
		stosb
bth999:		pop	si
		pop	cx
		pop	bx
		ret
os2bth		endp

HEX_code	ends
		end	main
