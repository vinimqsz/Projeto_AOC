# =============================================================
# Grupo: Adriano Lucas, Emmanuel Nascimento, Renato Barbosa e Vinícius Marques
# Atividade: 1VA
# Disciplina: Arquitetura e Organização de Computadores
# Semestre Letivo: 4o
# Questão: Implementação de funções string.h e Echo MMIO
# Descrição: 
#   Este arquivo contém a implementação das funções strcpy, memcpy,
#   strcmp, strncmp, strcat da biblioteca string.h em MIPS Assembly,
#   um programa principal para testar essas funções e uma rotina de
#   Echo usando MMIO para teclado e display.
# =============================================================

.data
# Strings de teste para as funções
src:    .asciiz "Hello"      # String fonte para cópia
dest:   .space 32            # Buffer para strings concatenadas
other:  .asciiz " World"     # String para concatenação
str1:   .asciiz "abc"        # String 1 para comparação
str2:   .asciiz "abd"        # String 2 para comparação
test1:  .asciiz "Test1"      # String para teste de memcpy
test2:  .asciiz "Test2"      # String para teste de memcpy

.text
.globl main

# ======================================
# Programa principal (main)
# ======================================
main:
    # Teste strcpy: copia "Hello" para dest
    la $a0, dest        # Carrega endereço de destino em $a0
    la $a1, src         # Carrega endereço de origem em $a1
    jal strcpy          # Chama função strcpy

    # Imprime resultado da cópia
    li $v0, 4           # Código de syscall para imprimir string
    la $a0, dest        # Endereço da string a imprimir
    syscall             
    li $v0, 11          # Código para imprimir caractere
    li $a0, '\n'        # Caractere nova linha
    syscall             

    # Teste strcat: concatena " World" em dest
    la $a0, dest        # Carrega endereço do destino
    la $a1, other       # Carrega endereço da string a concatenar
    jal strcat          # Chama função strcat

    # Imprime resultado da concatenação
    li $v0, 4           # Código para imprimir string
    la $a0, dest        # Endereço da string resultante
    syscall             
    li $v0, 11          # Código para imprimir caractere
    li $a0, '\n'        # Nova linha
    syscall             

    # Teste memcpy: copia 5 bytes de test2 para test1
    la $a0, test1       # Endereço de destino
    la $a1, test2       # Endereço de origem
    li $a2, 5           # Número de bytes a copiar
    jal memcpy          # Chama memcpy

    # Imprime resultado da cópia de memória
    li $v0, 4           # Código para imprimir string
    la $a0, test1       # String modificada
    syscall             
    li $v0, 11          # Código para imprimir caractere
    li $a0, '\n'        # Nova linha
    syscall             

    # Teste strcmp: compara str1 com ela mesma (deve ser igual)
    la $a0, str1        # Primeira string
    la $a1, str1        # Segunda string (mesma da primeira)
    jal strcmp          # Chama strcmp
    move $a0, $v0       # Move resultado para impressão
    li $v0, 1           # Código para imprimir inteiro
    syscall             
    li $v0, 11          # Código para imprimir caractere
    li $a0, '\n'        # Nova linha
    syscall             

    # Teste strcmp: compara "abc" com "abd" (deve ser negativo)
    la $a0, str1        # String "abc"
    la $a1, str2        # String "abd"
    jal strcmp          # Chama strcmp
    move $a0, $v0       # Move resultado
    li $v0, 1           # Imprime inteiro
    syscall             
    li $v0, 11          # Imprime caractere
    li $a0, '\n'        # Nova linha
    syscall             

    # Teste strncmp: compara apenas 2 primeiros caracteres de "abc" e "abd" (deve ser igual)
    la $a0, str1        # String "abc"
    la $a1, str2        # String "abd"
    li $a2, 2           # Compara apenas 2 caracteres
    jal strncmp         # Chama strncmp
    move $a0, $v0       # Move resultado
    li $v0, 1           # Imprime inteiro
    syscall             
    li $v0, 11          # Imprime caractere
    li $a0, '\n'        # Nova linha
    syscall             

    # Entra no modo Echo MMIO (loop infinito)
    j mmio_echo

# ======================================
# Função: strcpy = String Copy
# Descrição: Copia string de origem para destino
# Parâmetros:
#   $a0 - endereço do destino
#   $a1 - endereço da origem
# Retorno:
#   $v0 - endereço original do destino
# ======================================
strcpy:
    move $t5, $a0       # Salva endereço original do destino
    
strcpy_loop:
    lb $t0, 0($a1)      # Carrega byte da origem
    sb $t0, 0($t5)      # Armazena byte no destino
    beqz $t0, strcpy_done # Se byte for NULL, termina
    addi $t5, $t5, 1    # Avança ponteiro do destino
    addi $a1, $a1, 1    # Avança ponteiro da origem
    j strcpy_loop       # Repete o loop
    
strcpy_done:
    move $v0, $a0       # Retorna endereço original do destino
    jr $ra              # Retorna ao chamador

# ======================================
# Função: memcpy = Memory Copy
# Descrição: Copia blocos de memória
# Parâmetros:
#   $a0 - endereço do destino
#   $a1 - endereço da origem
#   $a2 - número de bytes a copiar
# Retorno:
#   $v0 - endereço original do destino
# ======================================
memcpy:
    move $v0, $a0       # Salva endereço original do destino
    move $t2, $a2       # Configura contador de bytes
    
memcpy_loop:
    beqz $t2, memcpy_done # Se contador = 0, termina
    lb $t0, 0($a1)      # Carrega byte da origem
    sb $t0, 0($a0)      # Armazena byte no destino
    addi $a0, $a0, 1    # Avança destino
    addi $a1, $a1, 1    # Avança origem
    addi $t2, $t2, -1   # Decrementa contador
    j memcpy_loop       # Repete o loop
    
memcpy_done:
    jr $ra              # Retorna ao chamador

# ======================================
# Função: strcmp = String Comparator
# Descrição: Compara duas strings
# Parâmetros:
#   $a0 - endereço da primeira string
#   $a1 - endereço da segunda string
# Retorno:
#   $v0 - 0 (igual), negativo (str1 < str2), positivo (str1 > str2)
# ======================================
strcmp:
strcmp_loop:
    lb $t0, 0($a0)      # Carrega byte de str1
    lb $t1, 0($a1)      # Carrega byte de str2
    beqz $t0, strcmp_check # Se fim de str1, verifica str2
    beqz $t1, strcmp_pos # Se fim de str2, str1 é maior
    blt $t0, $t1, strcmp_neg # Se str1 < str2, retorna negativo
    bgt $t0, $t1, strcmp_pos # Se str1 > str2, retorna positivo
    addi $a0, $a0, 1    # Avança str1
    addi $a1, $a1, 1    # Avança str2
    j strcmp_loop       # Repete comparação
    
strcmp_check:
    beqz $t1, strcmp_eq # Se ambas terminaram, são iguais
strcmp_neg:
    li $v0, -1          # Retorna -1 (str1 < str2)
    jr $ra              
strcmp_pos:
    li $v0, 1           # Retorna 1 (str1 > str2)
    jr $ra              
strcmp_eq:
    li $v0, 0           # Retorna 0 (strings iguais)
    jr $ra              

# ======================================
# Função: strncmp = String N Comparator
# Descrição: Compara até n caracteres de duas strings
# Parâmetros:
#   $a0 - endereço da primeira string
#   $a1 - endereço da segunda string
#   $a2 - número máximo de caracteres a comparar
# Retorno:
#   $v0 - 0 (igual), negativo (str1 < str2), positivo (str1 > str2)
# ======================================
strncmp:
    li $v0, 0           # Inicializa retorno como 0 (igual)
    beqz $a2, strncmp_done # Se num=0, retorna 0 imediatamente
    
strncmp_loop:
    lb $t0, 0($a0)      # Carrega byte de str1
    lb $t1, 0($a1)      # Carrega byte de str2
    beqz $a2, strncmp_done # Se contador=0, termina
    beqz $t0, strncmp_check # Se fim de str1, verifica str2
    beqz $t1, strncmp_diff # Se fim de str2, strings diferem
    blt $t0, $t1, strncmp_neg # str1 < str2
    bgt $t0, $t1, strncmp_pos # str1 > str2
    addi $a0, $a0, 1    # Avança str1
    addi $a1, $a1, 1    # Avança str2
    addi $a2, $a2, -1   # Decrementa contador
    j strncmp_loop      # Continua comparação
    
strncmp_check:
    beqz $t1, strncmp_done # Se str2 também terminou, são iguais
strncmp_neg:
    li $v0, -1          # Retorna -1
    jr $ra              
strncmp_pos:
    li $v0, 1           # Retorna 1
    jr $ra              
strncmp_diff:
    sub $v0, $t0, $t1   # Calcula diferença ASCII
strncmp_done:
    jr $ra              # Retorna ao chamador

# ======================================
# Função: strcat = String Concatenator
# Descrição: Concatena duas strings
# Parâmetros:
#   $a0 - endereço do destino
#   $a1 - endereço da origem
# Retorno:
#   $v0 - endereço original do destino
# ======================================
strcat:
    move $t0, $a0       # Salva endereço original do destino
    
strcat_find_end:
    lb $t1, 0($t0)      # Carrega byte do destino
    beqz $t1, strcat_copy # Se NULL, inicia cópia
    addi $t0, $t0, 1    # Avança no destino
    j strcat_find_end   # Continua procurando fim
    
strcat_copy:
    lb $t1, 0($a1)      # Carrega byte da origem
    sb $t1, 0($t0)      # Armazena no destino
    beqz $t1, strcat_done # Se NULL, termina
    addi $t0, $t0, 1    # Avança destino
    addi $a1, $a1, 1    # Avança origem
    j strcat_copy       # Continua cópia
    
strcat_done:
    move $v0, $a0       # Retorna endereço original
    jr $ra              # Retorna ao chamador

# ======================================
# Rotina: mmio_echo = MMIO Echo
# Descrição: Implementa echo usando MMIO
#   Lê caracteres do teclado e imprime no display
#   usando técnica de polling
# ======================================
mmio_echo:
    # Configura endereços MMIO
    li $t1, 0xffff0000   # Endereço de controle do teclado
    li $t2, 0xffff0004   # Endereço de dados do teclado
    li $t3, 0xffff0008   # Endereço de controle do display
    li $t4, 0xffff000c   # Endereço de dados do display

poll_keyboard:
    # Verifica se há caractere disponível no teclado
    lw $t0, 0($t1)       # Lê registrador de controle
    andi $t0, $t0, 1     # Isola bit 0 (ready)
    beqz $t0, poll_keyboard # Se não há caractere, repete
    
    # Lê o caractere do teclado
    lw $a0, 0($t2)       # Carrega caractere pressionado
    
poll_display:
    # Verifica se display está pronto para receber
    lw $t0, 0($t3)       # Lê registrador de controle
    andi $t0, $t0, 1     # Isola bit 0 (ready)
    beqz $t0, poll_display # Se não está pronto, espera
    
    # Envia caractere para o display
    sw $a0, 0($t4)       # Escreve caractere no display
    j poll_keyboard      # Volta para verificar teclado