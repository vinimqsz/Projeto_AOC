# ======================================
# 	STRCMP = String Comparison
# ======================================

strcmp:
	# a0 = str1, $a1 = str2

strcmp_loop:
	lb $t0, 0($a0)		# Caractere de str1
	lb $t1, 0($a1)		# Caractere de str2
	beq $t0, $zero, strcmp_check_end
	bne $t0, $t1, strcmp_diff
	
	# Avança ambos
	addi $a0, $a0, 1
	addi $a1, $a1, 1
	j strcmp_loop

strcmp_check_end:
	bne $t1, $zero, strcmp_diff	# Se str2 ainda tiver coisas, são diferentes
	li $v0, 0
	jr $ra


strcmp_diff:
	sub $v0, $t0, $t1	# resultado de diferença ASCII
	jr $ra