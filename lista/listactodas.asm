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

# ======================================
# 	STRCAT = String Concatenate
# ======================================

strcat:
    # $a0 = destination, $a1 = source
    move $t0, $a0       # Salva destino original
    
strcat_find_end:
    lb $t1, 0($t0)      # Carrega byte do destino
    beqz $t1, strcat_copy  # Se for null, começa a copiar
    addi $t0, $t0, 1    # Avança no destino
    j strcat_find_end
    
strcat_copy:
    lb $t1, 0($a1)      # Carrega byte da fonte
    sb $t1, 0($t0)      # Armazena no destino
    beqz $t1, strcat_done  # Se for null, termina
    addi $t0, $t0, 1    # Avança destino
    addi $a1, $a1, 1    # Avança fonte
    j strcat_copy
    
strcat_done:
    move $v0, $a0       # Retorna destino original
    jr $ra
    
    

# ======================================
# 		MAIN
# ======================================

.data
src:    .asciiz "Hello"
dest:   .space 32
other:  .asciiz " World"

.text
main:
    # strcpy(dest, src)
    la $a0, dest
    la $a1, src
    jal strcpy

    # strcat(dest, other)
    la $a0, dest
    la $a1, other
    jal strcat

    # imprime resultado
    li $v0, 4
    la $a0, dest
    syscall

    # halt
    li $v0, 10
    syscall
