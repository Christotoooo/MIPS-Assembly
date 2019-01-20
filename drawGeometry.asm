##
##  CHRISTOPHER ZHENG 260760794
##

.data  # start data segment with bitmapDisplay so that it is at 0x10010000
.globl bitmapDisplay # force it to show at the top of the symbol table
bitmapDisplay:    .space 0x80000  # Reserve space for memory mapped bitmap display
bitmapBuffer:     .space 0x80000  # Reserve space for an "offscreen" buffer
width:            .word 512       # Screen Width in Pixels, 512 = 0x200
height:           .word 256       # Screen Height in Pixels, 256 = 0x100

lineCount   :     .space 4        # int containing number of lines
lineData:         .space 0x4800   # space for teapot line data
lineDataFileName: .asciiz "teapotLineData.bin"
errorMessage:     .asciiz "Error: File must be in directory where MARS is started."

# TODO: declare other data you need or want here!

R:		.float
0.9994 0.0349 0 0
-0.0349 0.9994 0 0
0 0 1 0
0 0 0 1

M:		.float
331.3682, 156.83034, -163.18181, 1700.7253
-39.86386, -48.649902, -328.51334, 1119.5535
0.13962941, 1.028447, -0.64546686, 0.48553467
0.11424224, 0.84145665, -0.52810925, 6.3950152

tempMatrixResult:	.space 8



.text
##################################################################
# main entry point
# We will use save registers here without saving and restoring to
# the stack only because this is the main function!  All other 
# functions MUST RESPECT REGISTER CONVENTIONS
main:	la $a0 lineDataFileName
	la $a1 lineData
	la $a2 lineCount
	jal loadLineData
	la $s0 lineData 	# keep buffer pointer handy for later
	la $s1 lineCount
	lw $s1 0($s1)	   	# keep line count handy for later

	# TODO: write your test code here, as well as your final 
	# animation loop.  We will likewise test individually 
	# the functions that you implement below.
	
######start of the main while loop
mainWhileLoop:
		move $a0 $s0
		move $a1 $s1

		#allocate stack
		addi $sp $sp -12

		#store data into stack
		sw $a1 8($sp)
		sw $a0 4($sp)
		sw $ra 0($sp)

		#call draw 3d lines
		jal draw3DLines

		#re-load data back
		lw $a1 8($sp)
		lw $a0 4($sp)
		lw $ra 0($sp)

		#rotate 3d lines
		jal rotate3DLines

		#copy off-screen buffer
		jal copyBuffer

		#set screen to black
		li $a0 0x00000000
		jal clearBuffer

		#re-load data back
		lw $s1 8($sp)
		lw $s0 4($sp)
		lw $ra 0($sp)

		#restore stack
		addi $sp $sp 12

		j mainWhileLoop

	##########end of the main while loop
		
		
		li $v0, 10      # load exit call code 10 into $v0
		syscall         # call operating system to exit
        
        

###############################################################
# void clearBuffer( int colour )
clearBuffer:
		move $s0 $a0 #save colour at s0
		la $t0 bitmapBuffer
		li $t1 0
		li $t2 0x8000
		
repeatClearDisplay:
		sw $a0 0($t0)
		sw $a0 4($t0)
		sw $a0 8($t0)
		sw $a0 12($t0)
		addi $t0 $t0 16
		addi $t1 $t1 1
		beq $t2 $t1 finClearDisplay
		j repeatClearDisplay
		
finClearDisplay:
		jr $ra

###############################################################
# copyBuffer()
copyBuffer:
		la $a0 bitmapBuffer #off-screen buffer
		la $a1 bitmapDisplay #on-screen buffer
		li $t2 0          #counter
		li $t3 0x8000
repeatCopyToDisplay:
		lw $t0 0($a0)
		sw $t0 0($a1)
		lw $t0 4($a0)
		sw $t0 4($a1)
		lw $t0 8($a0)
		sw $t0 8($a1)
		lw $t0 12($a0)
		sw $t0 12($a1)
		addi $a0 $a0 16
		addi $a1 $a1 16
		addi $t2 $t2 1
		beq $t3 $t2 finCopyToDisplay
		j repeatCopyToDisplay
finCopyToDisplay:
		jr $ra

###############################################################
# drawPoint( int x, int y ) 
drawPoint: 
		li $t0 0x0000ff00   #save green colour to $t0
		#check bounds
		addi $t5 $0 512
		addi $t6 $0 256
		sltu $t4 $a0 $0
		beq $t4 1 finDrawPoint
		sltu $t4 $t5 $a0
		beq $t4 1 finDrawPoint
		sltu $t4 $a1 $0
		beq $t4 1 finDrawPoint
		sltu $t4 $t6 $a1
		beq $t4 1 finDrawPoint
		
		la $s0 bitmapBuffer #load the initial address to $s0
		sll $t1 $a1 9   #save $t1 with w*y
		add $t1 $t1 $a0 #save t1 with x + w*y
		sll $t1 $t1 2   #save t1 with 4(x +w*y)
		add $t1 $t1 $s0 #save b+4(x +w*y)
		sw $t0 0($t1)
		j finDrawPoint
finDrawPoint:
		jr $ra

###############################################################
# void drawline( int x0, int y0, int x1, int y1 )
drawLine:
		li $t0 1 #offsetx = 1
		li $t1 1 #offsety = 1
		move $s0 $a0 # x = x0
		move $s1 $a1 # y = y0
		
		sub $t2 $a2 $a0 # dx = x1 - x0
		sub $t3 $a3 $a1 # dy = y1 - y0
		
		slt $t4 $t2 $0 #$t4 = 1 if dx < 0
		bne $t4 $0 L1

Loop1Back:		
		slt $t4 $t3 $0 #$t4 = 1 if dy < 0
		bne $t4 $zero L2

Loop2Back:		
		move $a0 $s0
		move $a1 $s1
		addi $sp $sp -36
		sw $ra 0($sp)
		sw $t0 4($sp)
		sw $t1 8($sp)
		sw $t2 12($sp)
		sw $t3 16($sp)
		sw $s0 20($sp)
		sw $s1 24($sp)
		sw $a2 28($sp)
		sw $a3 32($sp)
		jal drawPoint
		lw $a3 32($sp) #y1
		lw $a2 28($sp) #x1
		lw $s1 24($sp) #y
		lw $s0 20($sp) #x
		lw $t3 16($sp) #dy
		lw $t2 12($sp) #dx
		lw $t1 8($sp) #offsety
		lw $t0 4($sp) #offsetx
		lw $ra 0($sp)
		addi $sp $sp 36
		slt $t4 $t3 $t2 # $t4 = 1 if dx > dy
		bne $t4 $0 option1
		j option2

option1:
		move $s2 $t2 #error = dx
		j WhileLoop1
		
WhileLoop1:		
		beq $s0 $a2 finDrawLine	
		add $t4 $t3 $t3
		sub $s2 $s2 $t4 #error = error - 2dy
		slt $t4 $s2 $zero 
		bne $t4 $zero FirstError
		j No_error1

FirstError: 	
		add $s1 $s1 $t1 #y = y + offsety
		add $t4 $t2 $t2 
		add $s2 $s2 $t4 #error = error + 2dx

No_error1:	
		add $s0 $s0 $t0
		move $a0 $s0
		move $a1 $s1
		addi $sp $sp -36
		sw $ra 0($sp)
		sw $t0 4($sp)
		sw $t1 8($sp)
		sw $t2 12($sp)
		sw $t3 16($sp)
		sw $s0 20($sp)
		sw $s1 24($sp)
		sw $a2 28($sp)
		sw $a3 32($sp)
		jal drawPoint
		lw $a3 32($sp) #y1
		lw $a2 28($sp) #x1
		lw $s1 24($sp) #y
		lw $s0 20($sp) #x
		lw $t3 16($sp) #dy
		lw $t2 12($sp) #dx
		lw $t1 8($sp) #offsety
		lw $t0 4($sp) #offsetx
		lw $ra 0($sp)
		addi $sp $sp 36
		j WhileLoop1
		
option2: 
		move $s2 $t3 #error = dy
		j WhileLoop2
		
WhileLoop2:
		beq $s1 $a3 finDrawLine	
		add $t4 $t2 $t2
		sub $s2 $s2 $t4 #error = error - 2dx
		slt $t4 $s2 $0 
		bne $t4 $0 SecondError
		j No_error2

SecondError: 	
		add $s0 $s0 $t0 #x = x + offsetx
		add $t4 $t3 $t3 
		add $s2 $s2 $t4 #error = error + 2dy

No_error2:	
		add $s1 $s1 $t1 #y=y+offsety
		move $a0 $s0
		move $a1 $s1
		addi $sp $sp -36
		sw $ra 0($sp)
		sw $t0 4($sp)
		sw $t1 8($sp)
		sw $t2 12($sp)
		sw $t3 16($sp)
		sw $s0 20($sp)
		sw $s1 24($sp)
		sw $a2 28($sp)
		sw $a3 32($sp)
		jal drawPoint
		lw $a3 32($sp) #y1
		lw $a2 28($sp) #x1
		lw $s1 24($sp) #y
		lw $s0 20($sp) #x
		lw $t3 16($sp) #dy
		lw $t2 12($sp) #dx
		lw $t1 8($sp) #offsety
		lw $t0 4($sp) #offsetx
		lw $ra 0($sp)
		addi $sp $sp 36
		j WhileLoop2
		
L1:		sub $t2 $0 $t2 # dx = -dx
		li $t0 -1
		j Loop1Back	
		
L2:		sub $t3 $0 $t3 # dx = -dx
		li $t1 -1	# offsety = -1
		j Loop2Back	

finDrawLine:		
		jr $ra

###############################################################
# void mulMatrixVec( float* M, float* vec, float* result )
mulMatrixVec:
		##########first row * vec
		lwc1 $f4 0($a1)
		lwc1 $f3 0($a0)
		mul.s $f5 $f4 $f3

		lwc1 $f4 4($a1)
		lwc1 $f3 4($a0)
		mul.s $f6 $f4 $f3
		add.s $f5 $f5 $f6

		lwc1 $f4 8($a1)
		lwc1 $f3 8($a0)
		mul.s $f6 $f4 $f3
		add.s $f5 $f5 $f6

		lwc1 $f4 12($a1)
		lwc1 $f3 12($a0)
		mul.s $f6 $f4 $f3
		add.s $f5 $f5 $f6
		swc1 $f5 0($a2)
		
		##########second row * vec
		addi $a0 $a0 16
		lwc1 $f4 0($a1)
		lwc1 $f3 0($a0) 
		mul.s $f5 $f4 $f3

		lwc1 $f4 4($a1)
		lwc1 $f3 4($a0)
		mul.s $f6 $f4 $f3
		add.s $f5 $f5 $f6

		lwc1 $f4 8($a1)
		lwc1 $f3 8($a0)
		mul.s $f6 $f4 $f3
		add.s $f5 $f5 $f6
		
		lwc1 $f4 12($a1)
		lwc1 $f3 12($a0)
		mul.s $f6 $f4 $f3
		add.s $f5 $f5 $f6
		swc1 $f5 4($a2)
		

		#########third row * vec
		addi $a0 $a0 16
		lwc1 $f4 0($a1)
		lwc1 $f3 0($a0) 
		mul.s $f5 $f4 $f3

		lwc1 $f4 4($a1)
		lwc1 $f3 4($a0)
		mul.s $f6 $f4 $f3
		add.s $f5 $f5 $f6

		lwc1 $f4 8($a1)
		lwc1 $f3 8($a0)
		mul.s $f6 $f4 $f3
		add.s $f5 $f5 $f6

		lwc1 $f4 12($a1)
		lwc1 $f3 12($a0)
		mul.s $f6 $f4 $f3
		add.s $f5 $f5 $f6
		swc1 $f5 8($a2)
		
		#############fourth row * vec
		addi $a0 $a0 16
		lwc1 $f4 0($a1)
		lwc1 $f3 0($a0) 
		mul.s $f5 $f4 $f3

		lwc1 $f4 4($a1)
		lwc1 $f3 4($a0)
		mul.s $f6 $f4 $f3
		add.s $f5 $f5 $f6

		lwc1 $f4 8($a1)
		lwc1 $f3 8($a0)
		mul.s $f6 $f4 $f3
		add.s $f5 $f5 $f6

		lwc1 $f4 12($a1)
		lwc1 $f3 12($a0)
		mul.s $f6 $f4 $f3
		add.s $f5 $f5 $f6
		swc1 $f5 12($a2)		
		
		jr $ra
        
###############################################################
# (int x,int y) = point2Display( float* vec )
point2Display:
			#load four arguments from the vector
			lwc1 $f6 12($a0)
			lwc1 $f5 8($a0)   #not used
			lwc1 $f4 4($a0)
			lwc1 $f3 0($a0)
      		
      		#convert first result
      		div.s $f1 $f3 $f6
      		cvt.w.s $f0 $f1
      		mfc1 $v0 $f0

      		#convert second result
      		div.s $f1 $f4 $f6
      		cvt.w.s $f0 $f1
      		mfc1 $v1 $f0

	        jr $ra
        
###############################################################
# draw3DLines( float* lineData, int ineCount )
draw3DLines:
				#store linecount at $t0
                move $t0 $a1 
                #t1 counter
                li $t1 0   

LineWhileLoop:	
				#end case: when reach the lineCount
				beq $t0 $t1 finDraw3DLines

				#point to the 2nd point of one line
                addi $a1 $a0 16  
                la $a2 tempMatrixResult
                
                addi $sp $sp -32

                #store data in the stack
                sw $t0 20($sp)
				sw $t1 16($sp)
				sw $a2 12($sp) 
				sw $a1 8($sp) # 2nd point address
				sw $a0 4($sp) # 1st point address
				sw $ra 0($sp)
				
				#cal the first matrix output
				lw $a1 4($sp)
				la $a0 M
                jal mulMatrixVec 
                
                #cal the first point into 2D
                la $a0 tempMatrixResult
                jal point2Display
                sw $v1 28($sp)     
                sw $v0 24($sp)
                
                lw $a2 12($sp)
                lw $a1 8($sp)
                la $a0 M
                jal mulMatrixVec
                
                #cal the 2rd point into 2D
                la $a0 tempMatrixResult
                jal point2Display
                
                #2 outputs
                move $a1 $v1
                move $a0 $v0
                lw $a3 28($sp)
                lw $a2 24($sp)
                #draw the line using two points (4 arguments)
                jal drawLine
                
                #restore the data back
                lw $ra 0($sp)
                lw $a0 4($sp)
                lw $a1 8($sp)
                lw $a2 12($sp)
                lw $t1 16($sp)
                lw $t0 20($sp)

                #restore the stack
                addi $sp $sp 32

                #increment the counter
				addi $t1 $t1 1

				#move the input pointer into next line 
				#(next two points)
				addi $a0 $a0 32

				#call back the while loop
				j LineWhileLoop      

 finDraw3DLines:	
                jr $ra

###############################################################
# rotate3DLines( float* lineData, int lineCount )
rotate3DLines:
                move $t0 $a1 #store linecount at $t0
                #counter
                li $t1 0

RotateWhileLoop:	
				beq $t0 $t1 finRotate3DLines
                addi $a1 $a0 16  #point to the end point
                
		        addi $sp $sp -20
				sw $ra 0($sp)
				sw $a1 8($sp) #2nd point address
				sw $a0 4($sp) #1st point address
				
				sw $t0 16($sp)
				sw $t1 12($sp)
				
				#call 1st matrix
				lw $a2 4($sp)  #a2 will be overrun
				lw $a1 4($sp)
				la $a0 R
                jal mulMatrixVec 
                
                
                #call 2nd matrix
                lw $a2 8($sp)  #a2 will be overrun
                lw $a1 8($sp)
                la $a0 R
                jal mulMatrixVec
                
                #load back the data
                lw $ra 0($sp)
                lw $a0 4($sp)
                lw $a1 8($sp)
                lw $t1 12($sp)
                lw $t0 16($sp)

                #restore stack
                addi $sp $sp 20

				#go next line
				addi $a0 $a0 32

				#increment the counter
				addi $t1 $t1 1

				j RotateWhileLoop

finRotate3DLines:	
		jr $ra        
        
        
        
        
        
###############################################################
# void loadLineData( char* filename, float* data, int* count )
#
# Loads the line data from the specified filename into the 
# provided data buffer, and stores the count of the number 
# of lines into the provided int pointer.  The data buffer 
# must be big enough to hold the data in the file being loaded!
#
# Each line comes as 8 floats, x y z w start point and end point.
# This function does some error checking.  If the file can't be opened, it 
# forces the program to exit and prints an error message.  While other
# errors may happen on reading, note that no other errors are checked!!  
#
# Temporary registers are used to preserve passed argumnets across
# syscalls because argument registers are needed for passing information
# to different syscalls.  Temporary usage:
#
# $t0 int pointer for line count,  passed as argument
# $t1 temporary working variable
# $t2 filedescriptor
# $t3 number of bytes to read
# $t4 pointer to float data,  passed as an argument
#
loadLineData:	move $t4 $a1 		# save pointer to line count integer for later		
		move $t0 $a2 		# save pointer to line count integer for later
			     		# $a0 is already the filename
		li $a1 0     		# flags (0: read, 1: write)
		li $a2 0     		# mode (unused)
		li $v0 13    		# open file, $a0 is null-terminated string of file name
		syscall			# $v0 will contain the file descriptor
		slt $t1 $v0 $0   	# check for error, if ( v0 < 0 ) error! 
		beq $t1 $0 skipError
		la $a0 errorMessage 
		li $v0 4    		# system call for print string
		syscall
		li $v0 10    		# system call for exit
		syscall
skipError:	move $t2 $v0		# save the file descriptor for later
		move $a0 $v0         	# file descriptor (negative if error) as argument for write
  		move $a1 $t0       	# address of buffer to which to write
		li  $a2 4	    	# number of bytes to read
		li  $v0 14          	# system call for read from file
		syscall		     	# v0 will contain number of bytes read
		
		lw $t3 0($t0)	     	# read line count from memory (was read from file)
		sll $t3 $t3 5  	     	# number of bytes to allocate (2^5 = 32 times the number of lines)			  		
		
		move $a0 $t2		# file descriptor
		move $a1 $t4		# address of buffer 
		move $a2 $t3    	# number of bytes 
		li  $v0 14           	# system call for read from file
		syscall               	# v0 will contain number of bytes read

		move $a0 $t2		# file descriptor
		li  $v0 16           	# system call for close file
		syscall		     	
		
		jr $ra        
