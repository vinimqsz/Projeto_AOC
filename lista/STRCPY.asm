# ======================================
# 	STRCPY = String Copy
# ======================================
strcpy:
	# a0 = dest, a1 = source
    	move $t5, $a0		# copia dest para não perder
strcpy_loop:
    	lb $t0, 0($a1)		# Carrega byte de source
    	sb $t0, 0($t5)		# Salva byte em dest
    	beqz $t0, strcpy_done	# Se for \0, termina
    	addi $t5, $t5, 1	# Avança dest
    	addi $a1, $a1, 1	# Avança source
    	j strcpy_loop
strcpy_done:
   	move $v0, $a0		# Retorna o destino original
    	jr $ra			# Pula pro registro anterior