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
    