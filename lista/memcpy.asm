# ======================================
# 	MEMCPY = Memory Copy
# ======================================

memcpy:
	# $a0 = dest, $a1 = source, $a2 = num
	move $t2, $a2 		# contador de bytes
	
memcpy_loop:
	beqz $t2, memcpy_done
	lb $t0, 0($a1)
	sb $t0, 0($a0)
	addi $a0, $a0, 1
	addi $a1, $a1, 1
	addi $t2, $t2, -1
	j memcpy_loop
	
memcpy_done:
	move $v0, $a0
	jr $ra
	