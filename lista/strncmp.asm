# ======================================
#     STRNCMP = String N Comparison
# ======================================

strcnmp:
	# $a0 = str1, $a1 = str2, $a3 = num
	move $t4, $a3 	# contador de comparação

strcnmp_loop:
	beqz $t4, strcnmp_equal
	lb $t0, 0($a0)
	lb $t1, 0($a1)
	
	beq $t0, $zero, strcnmp_check_end
	bne $t0, $t1, strcnmp_diff
	
	addi $a0, $a0, 1
	addi $a1, $a1, 1
	addi $t4, $t4, -1
	j strcnmp_loop

strcnmp_check_end:
	bne $t1, $zero, strcnmp_diff
strcnmp_equal:
	li $v0, 0
	jr $ra

strcnmp_diff:
	sub $v0, $t0, $t1
	jr $ra
