# ZHENG
# Chuanxi
# 260760794

## littletrick: add a space between displayBuffer and errorBuffer can separate those two chunks
## of memory so that we can dramatically decrease the number of cache misses because they are now 
## less likely to hit into each other's "territory"

#Q1: Yes, they do fall into the same block of memory in the direct
#before my optimization. They two are trying to be read at the time
#and so after I shift the address of memory they are not that 
#colliding anymore. I chose to shift the buffer by half the size of the cache line width (64 decimal).

#Q2: Yes, it matters because of the effect on the cache misses. Shifting
#the buffers makes them not be read from the cache in the same place.


.data
displayBuffer:  .space 0x40000 # space for 512x256 bitmap display
littletrick: .space 0x40 #same as 24640 decimal (to improve performance) 
errorBuffer:    .space 0x40000 # space to store match function
templateBuffer: .space 0x100   # space for 8x8 template
imageFileName:    .asciiz "pxlcon512x256cropgs.raw" 
templateFileName: .asciiz "template8x8gs.raw"
# struct bufferInfo { int *buffer, int width, int height, char* filename }
imageBufferInfo:    .word displayBuffer  512 128  imageFileName
errorBufferInfo:    .word errorBuffer    512 128  0
templateBufferInfo: .word templateBuffer 8   8    templateFileName

.text
main:	la $a0, imageBufferInfo
	jal loadImage
	la $a0, templateBufferInfo
	jal loadImage
	la $a0, imageBufferInfo
	la $a1, templateBufferInfo
	la $a2, errorBufferInfo
	jal matchTemplateFast      # MATCHING DONE HERE
	la $a0, errorBufferInfo
	jal findBest
	la $a0, imageBufferInfo
	move $a1, $v0
	jal highlight
	la $a0, errorBufferInfo	
	jal processError
	li $v0, 10		# exit
	syscall
	

##########################################################
# matchTemplate( bufferInfo imageBufferInfo, bufferInfo templateBufferInfo, bufferInfo errorBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
matchTemplate:	
		lw $a3, 0($a0) # int *imageBuffer
		lw $t5, 0($a1) # address of templateBuffer
		lw $t6, 0($a2) # address of errorBuffer
		
		lw $a2, 4($a0) # int width
		subi $a2, $a2, 7 
		
		lw $a1, 8($a0) # int height
		subi $a1, $a1, 7 

		add $t1, $0, $0 # initialize mutable height at zero
		
Loop1:		
		# check if height is done
		slt $t0, $t1, $a1 
		beq $t0, $zero, ImageHeightFin 
		#if met, end outermost loop
		add $t2, $0, $0
		
Loop2: 
		 # width is done
		slt $t0, $t2, $a2
		beq $t0, $zero, ImageWidthFin #end width loop
		
		#init template loop height
		add $t3, $0, $0 
		# for the SAD[x,y]
		add $v0, $0, $0 

TemplateHeightLoop:
		slti $t0, $t3, 8 # done height of template

		beq $t0,$zero, TemplateHeightFin 
		#jump to templateWidthFin -> Loop1 to next height
		
		#init template loop width
		add $t4, $0, $0 

TemplateWidthLoop:	
		slti $t0, $t4, 8 # see if finished looping over width of the template
		beq $t0,$zero, TemplateWidthFin # if yes, move on to next width unit

        ######################
		# $a3 address of displayBuffer $t1 current height of image offset (outer)
		# $t2 current width of image offset (inner) $t3 current height of template (also offset for image width) (outer)
		# $t4 current width of template (also offset for image height) (inner)
		# $t5 address of templateBuffer $t6 address of errorBuffer
		# $a1 max height of template - 7 in pixels $a2 max width of template - 7 in pixels
		######################
		
		# calculate absolute differences and set values in errorbuffer here
		# ONE get base pixel offset
		addi $t0, $a2, 7 
		addi $a0, $0, 4 

		# multiply full width by current height of image
		mult $t1, $t0 
		mflo $t7 # (image height offset)
		#get the base pixel offset/4
		add $t7, $t2, $t7

		
		# TWO add template offset to base pixel offset
		# 512 * current height of template
		mult $t3, $t0 
		# template height offset
		mflo $t8 
		# + template width offset
		add $t8, $t8, $t4 
		 
		 # add template height and width offset to base offset
		add $t7, $t8, $t7 
		mult $a0, $t7 # *4.
		# image offset + template offset
		mflo $t7 
		
		# displayBuffer address + $t7  ===> image pixel address
		add $t7, $a3, $t7 
	
	    ##################################
		# t3 current template height  t4 current template width  t5 templateBuffer base address
		# t7 displayBuffer address of image pixel t8 errorBuffer address of error memory storage
		# t9 template height and width offset
		##################################
		
		addi $a0, $0, 8 
		# 8*template height
		mult $t3, $a0 
		# height offset of template
		mflo $t8 
		# add template width offset
		add $t8, $t8, $t4 
		
		addi $a0, $0, 4 
		mult $t8, $a0 # word offset
		mflo $t8 
		# template address location
		add $t9, $t8, $t5 
		# pixel value of image
		lbu $t7, 1($t7) 
		# pixel value of template
		lbu $t9, 1($t9) 
		
		# subtract the intensities =====>$t7
		subu $t7, $t7, $t9 
		abs $t7, $t7 #absolute value
		
None:		
		addu $v0, $t7, $v0 		
		#increment by one
		addi $t4, $t4, 1 
		j TemplateWidthLoop 
		
TemplateWidthFin: 	
		#increment by one
		addi $t3, $t3, 1 
		j TemplateHeightLoop 
		
TemplateHeightFin:	
		addi $a0, $a2, 7 #image full width
		mult $t1, $a0 # width * current height
		mflo $t7 
		add $t7, $t2, $t7 #base pixel offset/4
		
		add $a0, $0, 4 
		#word offset
		mult $a0, $t7 
		#word offset (x,y in SAD[x,y])
		mflo $t7
		add $t7, $t6, $t7
		
		 # save SAD to errorBuffer address
		sw $v0, 0($t7)
		# image width increment
		addi $t2, $t2, 1 
		j Loop2 
		
ImageWidthFin:	
		#image height increment
		addi $t1, $t1, 1 
		j Loop1 
		
ImageHeightFin:	
		#ultimate END
		jr $ra  
	
##########################################################
# matchTemplateFast( bufferInfo imageBufferInfo, bufferInfo templateBufferInfo, bufferInfo errorBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
matchTemplateFast:	
		lw $s1 8($a0) 
		addi $s1 $s1 -8 
		lw $s3 4($a2) 
		lw $s2 4($a0) 
		

		lw $a0 0($a0) 
		lw $a1 0($a1) 
		lw $a2 0($a2) 
		
		addi $s5 $0 0 

		########
		# s1: Image height -8
		# s2: Image width
		# s3: Error width
		# a0: Image address
		# a1: Template address
		# a2: Error address
		# s0: x counter
		# s5: j counter
		# s6: y counter
		#######


J:		
		#use v as a temp
		addi $v1 $0 8
		slt $v1 $s5 $v1
		beqz $v1 JFin
		
		# (j * template width + i) * 4
		#sll $t9 $s5 5 
		sll $t9 $s5 5

		add $t9 $t9 $a1 # Template addr + t0
		
		 # T[i][j]
		lbu $t0 0($t9)
		lbu $t1 4($t9) 
		lbu $t2 8($t9) 
		lbu $t3 12($t9) 
		lbu $t4 16($t9) 
		lbu $t5 20($t9) 
		lbu $t6 24($t9) 
		lbu $t7 28($t9) 


		addi $s6 $0 0 #init counter

Y:		
		#s1 height-8  s6 y counter
		#slt $v1 $s6 $s1 #y<height-8
		sgt $v1 $s6 $s1 # y<=height -8
		beq $v1 1 YFin


		addi $s0 $0 0 #init
		
		# v0 = y + j
		add $v0 $s5 $s6

X:		
		addi $v1 $s2 -7
		#slt $v1 $s0 $s2
		slt $v1 $s0 $v1
		beqz $v1 XFin

		#y * error width
		mult $s6 $s3 
		mflo $t8
		
		#y * error width + x
		add $t8 $t8 $s0 
		
		# (y * error width + x) * 4
		sll $t8 $t8 2 

		# add error addr => real offset
		add $t8 $t8 $a2 

		# s4 = SAD[x,y]
		lw $s4 0($t8) 
		
		# t9 = y + j
		#add $t9 $s5 $s6 
		
		# (y+j)*image width
		mult $v0 $s2 
		mflo $t9

		# (y+j)*image width +  x)
		add $t9 $t9 $s0 
		sll $t9 $t9 2
		add $t9 $t9 $a0 #offset
		
		##########FOR I-T##############

		lbu $s7 0($t9) 
		# I[x+0][y+j]
		sub $s7 $s7 $t0 
		# I - T
		abs $s7 $s7 
		add $s4 $s7 $s4 
		# s4 = SAD[x,y] + abs(I - T)

		lbu $s7 4($t9) 
		# I[x+1][y+j]
		sub $s7 $s7 $t1 
		# I - T
		abs $s7 $s7 
		add $s4 $s7 $s4 
		# s4 = SAD[x,y] + abs(I - T)


		lbu $s7 8($t9)
		 # I[x+2][y+j]
		sub $s7 $s7 $t2 
		# I - T
		abs $s7 $s7
		add $s4 $s7 $s4 
		# s4 = SAD[x,y] + abs(I - T)


		lbu $s7 12($t9) 
		# I[x+3][y+j]
		sub $s7 $s7 $t3 
		# I - T
		abs $s7 $s7 
		add $s4 $s7 $s4 
		# s4 = SAD[x,y] + abs(I - T)


		lbu $s7 16($t9) 
		# I[x+4][y+j]
		sub $s7 $s7 $t4 
		# I - T
		abs $s7 $s7 
		add $s4 $s7 $s4 
		# s4 = SAD[x,y] + abs(I - T)


		lbu $s7 20($t9) 
		# I[x+5][y+j]
		sub $s7 $s7 $t5 
		# I - T
		abs $s7 $s7 
		add $s4 $s7 $s4 
		# s4 = SAD[x,y] + abs(I - T)


		lbu $s7 24($t9) 
		# I[x+6][y+j]
		sub $s7 $s7 $t6 
		# I - T
		abs $s7 $s7 
		add $s4 $s7 $s4 
		# s4 = SAD[x,y] + abs(I - T)


		lbu $s7 28($t9) 
		# I[x+7][y+j]
		sub $s7 $s7 $t7 
		# I - T
		abs $s7 $s7 
		add $s4 $s7 $s4 
		# s4 = SAD[x,y] + abs(I - T)

		##### SAD[x,y]#########
		sw $s4 ($t8) 

		# x counter increment
		addi $s0 $s0 1 

		j X
		
XFin:		
		# y counter increment
		addi $s6 $s6 1 
		j Y
		
YFin:		
		# j counter increment
		addi $s5 $s5 1 
		j J
		
JFin:		addi $v0 $0 0 #
		addi $v1 $0 0
		jr $ra
	
	
###############################################################
# loadImage( bufferInfo* imageBufferInfo )
# NOTE: struct bufferInfo { int *buffer, int width, int height, char* filename }
loadImage:	lw $a3, 0($a0)  # int* buffer
		lw $a1, 4($a0)  # int width
		lw $a2, 8($a0)  # int height
		lw $a0, 12($a0) # char* filename
		mul $t0, $a1, $a2 # words to read (width x height) in a2
		sll $t0, $t0, 2	  # multiply by 4 to get bytes to read
		li $a1, 0     # flags (0: read, 1: write)
		li $a2, 0     # mode (unused)
		li $v0, 13    # open file, $a0 is null-terminated string of file name
		syscall
		move $a0, $v0     # file descriptor (negative if error) as argument for read
  		move $a1, $a3     # address of buffer to which to write
		move $a2, $t0	  # number of bytes to read
		li  $v0, 14       # system call for read from file
		syscall           # read from file
        		# $v0 contains number of characters read (0 if end-of-file, negative if error).
        		# We'll assume that we do not need to be checking for errors!
		# Note, the bitmap display doesn't update properly on load, 
		# so let's go touch each memory address to refresh it!
		move $t0, $a3	   # start address
		add $t1, $a3, $a2  # end address
loadloop:	lw $t2, ($t0)
		sw $t2, ($t0)
		addi $t0, $t0, 4
		bne $t0, $t1, loadloop
		jr $ra
		
		
#####################################################
# (offset, score) = findBest( bufferInfo errorBuffer )
# Returns the address offset and score of the best match in the error Buffer
findBest:	lw $t0, 0($a0)     # load error buffer start address	
		lw $t2, 4($a0)	   # load width
		lw $t3, 8($a0)	   # load height
		addi $t3, $t3, -7  # height less 8 template lines minus one
		mul $t1, $t2, $t3
		sll $t1, $t1, 2    # error buffer size in bytes	
		add $t1, $t0, $t1  # error buffer end address
		li $v0, 0		# address of best match	
		li $v1, 0xffffffff 	# score of best match	
		lw $a1, 4($a0)    # load width
        		addi $a1, $a1, -7 # initialize column count to 7 less than width to account for template
fbLoop:		lw $t9, 0($t0)        # score
		sltu $t8, $t9, $v1    # better than best so far?
		beq $t8, $zero, notBest
		move $v0, $t0
		move $v1, $t9
notBest:		addi $a1, $a1, -1
		bne $a1, $0, fbNotEOL # Need to skip 8 pixels at the end of each line
		lw $a1, 4($a0)        # load width
        		addi $a1, $a1, -7     # column count for next line is 7 less than width
        		addi $t0, $t0, 28     # skip pointer to end of line (7 pixels x 4 bytes)
fbNotEOL:	add $t0, $t0, 4
		bne $t0, $t1, fbLoop
		lw $t0, 0($a0)     # load error buffer start address	
		sub $v0, $v0, $t0  # return the offset rather than the address
		jr $ra
		

#####################################################
# highlight( bufferInfo imageBuffer, int offset )
# Applies green mask on all pixels in an 8x8 region
# starting at the provided addr.
highlight:	lw $t0, 0($a0)     # load image buffer start address
		add $a1, $a1, $t0  # add start address to offset
		lw $t0, 4($a0) 	# width
		sll $t0, $t0, 2	
		li $a2, 0xff00 	# highlight green
		li $t9, 8	# loop over rows
highlightLoop:	lw $t3, 0($a1)		# inner loop completely unrolled	
		and $t3, $t3, $a2
		sw $t3, 0($a1)
		lw $t3, 4($a1)
		and $t3, $t3, $a2
		sw $t3, 4($a1)
		lw $t3, 8($a1)
		and $t3, $t3, $a2
		sw $t3, 8($a1)
		lw $t3, 12($a1)
		and $t3, $t3, $a2
		sw $t3, 12($a1)
		lw $t3, 16($a1)
		and $t3, $t3, $a2
		sw $t3, 16($a1)
		lw $t3, 20($a1)
		and $t3, $t3, $a2
		sw $t3, 20($a1)
		lw $t3, 24($a1)
		and $t3, $t3, $a2
		sw $t3, 24($a1)
		lw $t3, 28($a1)
		and $t3, $t3, $a2
		sw $t3, 28($a1)
		add $a1, $a1, $t0	# increment address to next row	
		add $t9, $t9, -1		# decrement row count
		bne $t9, $zero, highlightLoop
		jr $ra

######################################################
# processError( bufferInfo error )
# Remaps scores in the entire error buffer. The best score, zero, 
# will be bright green (0xff), and errors bigger than 0x4000 will
# be black.  This is done by shifting the error by 5 bits, clamping
# anything bigger than 0xff and then subtracting this from 0xff.
processError:	lw $t0, 0($a0)     # load error buffer start address
		lw $t2, 4($a0)	   # load width
		lw $t3, 8($a0)	   # load height
		addi $t3, $t3, -7  # height less 8 template lines minus one
		mul $t1, $t2, $t3
		sll $t1, $t1, 2    # error buffer size in bytes	
		add $t1, $t0, $t1  # error buffer end address
		lw $a1, 4($a0)     # load width as column counter
        		addi $a1, $a1, -7  # initialize column count to 7 less than width to account for template
pebLoop:		lw $v0, 0($t0)        # score
		srl $v0, $v0, 5       # reduce magnitude 
		slti $t2, $v0, 0x100  # clamp?
		bne  $t2, $zero, skipClamp
		li $v0, 0xff          # clamp!
skipClamp:	li $t2, 0xff	      # invert to make a score
		sub $v0, $t2, $v0
		sll $v0, $v0, 8       # shift it up into the green
		sw $v0, 0($t0)
		addi $a1, $a1, -1        # decrement column counter	
		bne $a1, $0, pebNotEOL   # Need to skip 8 pixels at the end of each line
		lw $a1, 4($a0)        # load width to reset column counter
        		addi $a1, $a1, -7     # column count for next line is 7 less than width
        		addi $t0, $t0, 28     # skip pointer to end of line (7 pixels x 4 bytes)
pebNotEOL:	add $t0, $t0, 4
		bne $t0, $t1, pebLoop
		jr $ra
