##############################################################################
# Grupo: Adriano Lucas, Emmanuel Nascimento, Renato Barbosa e Vin�cius Marques
# Atividade: Projeto 1VA
# Disciplina: Arquitetura e Organiza��o de Computadores
# Semestre Letivo: 4o
# 
# Descri��o:
# Sistema de gerenciamento de condom�nio com shell interativo para cadastro:
# - Moradores (at� 5 por apartamento)
# - Ve�culos (1 carro ou 2 motos por apartamento)
# - Comandos para adicionar, remover, visualizar e limpar dados
# - Persist�ncia em arquivo bin�rio
#
# Principais componentes:
# 1. Parser de comandos com tokeniza��o de strings
# 2. Mapemento de apartamentos (40 unidades)
# 3. Armazenamento eficiente em arrays pr�-alocados
# 4. Opera��es CRUD para moradores e ve�culos
# 5. Sistema de arquivos com auto-cria��o e recupera��o de erros
##############################################################################

.data
### Constantes para syscall open #############################################
.eqv O_RDONLY 0
.eqv O_WRONLY 1
.eqv O_RDWR   2
.eqv O_CREAT  0x200
.eqv O_TRUNC  0x400

### SHELL E PARSING ##########################################################
# Prompt e buffers para entrada de comandos
banner:        .asciiz "CND-shell>> "     # Prompt de comando
buffer:        .align 2                   # Buffer de entrada 64 bytes
               .space 100                 
cmd_buffer:    .space 60                  # Buffer processamento comandos
tokens:        .space 80                  # 20 tokens * 4 bytes
token_count:   .word 0                    # Contador de tokens

### MAPEAMENTO DE APs ########################################################
ap_map: .word 101,102,103,104,201,202,203,204,301,302,303,304,401,402,403,404
        .word 501,502,503,504,601,602,603,604,701,702,703,704,801,802,803,804
        .word 901,902,903,904,1001,1002,1003,1004

### ARMAZENAMENTO DE DADOS ###################################################
ap_status:     .space 40      # 1 byte/AP: 0=vazio, 1=ocupado
qtd_moradores: .space 160     # 40 APs � 4 bytes
moradores:     .space 6000    # 40 APs � 5 moradores � 30 caracteres

tipo_veiculo:  .space 40      # Estado ve�culos (1 bit carro + 2 bits motos)
modelo_carro:  .space 800     # 40 APs � 20 bytes
cor_carro:     .space 600     # 40 APs � 15 bytes
modelo_moto1:  .space 800     # 40 APs � 20 bytes
cor_moto1:     .space 600     # 40 APs � 15 bytes
modelo_moto2:  .space 800     # 40 APs � 20 bytes
cor_moto2:     .space 600     # 40 APs � 15 bytes

### COMANDOS E STRINGS DE SA�DA ##############################################
# Identificadores de comandos
exit_cmd:      .asciiz "exit"
str_all:       .asciiz "all"
str_space:     .asciiz " "
str_percent:   .asciiz "%"

# Nomes de comandos
msg_ad_morador: .asciiz "ad_morador"
msg_rm_morador: .asciiz "rm_morador"
msg_ad_auto:    .asciiz "ad_auto"
msg_rm_auto:    .asciiz "rm_auto"
msg_limpar_ap:  .asciiz "limpar_ap"
msg_info_ap:    .asciiz "info_ap"
msg_info_geral: .asciiz "info_geral"
msg_salvar:     .asciiz "salvar"
msg_recarregar: .asciiz "recarregar"
msg_formatar:   .asciiz "formatar"

# Cabe�alhos para informa��es
str_ap:        .asciiz "AP: "
str_residents: .asciiz "Moradores:\n"
str_car:       .asciiz "Carro:\n"
str_moto:      .asciiz "Moto:\n"
str_model:     .asciiz "\tModelo: "
str_color:     .asciiz "\tCor: "

# Identificadores de tipo de ve�culo
str_car_cmd:   .asciiz "c"
str_moto_cmd:  .asciiz "m"

### ARQUIVO ##################################################################
filename:      .asciiz "condominio.dat"
empty_buffer:  .space 10080    # Tamanho total dos dados (40�1 + 40�4 + ...)

### MENSAGENS DO SISTEMA #####################################################
# Mensagens de erro
err_invalid_cmd:    .asciiz "Comando invalido\n"
err_invalid_ap:     .asciiz "Falha: AP invalido\n"
err_ap_full_res:    .asciiz "Falha: AP com numero max de moradores\n"
err_res_not_found:  .asciiz "Falha: morador nao encontrado\n"
err_ap_full_veh:    .asciiz "Falha: AP com numero max de automoveis\n"
err_invalid_type:   .asciiz "Falha: tipo invalido\n"
err_veh_not_found:  .asciiz "Falha: automovel nao encontrado\n"
err_file_open:      .asciiz "Erro: Falha ao abrir arquivo\n"
err_file_write:     .asciiz "Erro: Falha ao escrever no arquivo\n"
err_file_read:      .asciiz "Erro: Falha ao ler arquivo ou dados corrompidos\n"

# Mensagens de sucesso
success_add_res:    .asciiz "Morador adicionado com sucesso\n"
success_rem_res:    .asciiz "Morador removido com sucesso\n"
success_add_veh:    .asciiz "Veiculo adicionado com sucesso\n"
success_rem_veh:    .asciiz "Veiculo removido com sucesso\n"
success_clr_ap:     .asciiz "Apartamento limpo com sucesso\n"
success_save:       .asciiz "Dados salvos com sucesso\n"
success_load:       .asciiz "Dados carregados com sucesso\n"
success_reset:      .asciiz "Dados resetados com sucesso!\n"
msg_created:        .asciiz "Arquivo criado com dados iniciais zerados\n"

# Mensagens de informa��o
info_ap_empty:      .asciiz "Apartamento vazio\n"
info_general_non_empty: .asciiz "Nao vazios:\t"
info_general_empty:     .asciiz "Vazios:\t\t"
info_general_percent:   .asciiz "%\n"
info_general_total:     .asciiz "Total de apartamentos: 40\n"

.text
.globl main
##############################################################################
# PROGRAMA PRINCIPAL
#
# Descri��o:
# - Inicializa o sistema carregando dados de arquivo
# - Exibe prompt interativo para comandos
# - Processa comandos em loop at� receber 'exit'
# - Ao sair, salva automaticamente o estado
##############################################################################
main:
    # Carregamento inicial silencioso dos dados
    li $a0, 0
    jal load_from_file
    
main_loop:
    # Exibir prompt para usu�rio
    li $v0, 4
    la $a0, banner
    syscall

    # Ler entrada do usu�rio
    li $v0, 8
    la $a0, buffer
    li $a1, 64
    syscall
    
    # Remover newline da entrada
    jal remove_newline
    
    # Processar comando
    jal parse_command
    
    # Continuar loop principal
    j main_loop

    # Ponto de sa�da (nunca alcan�ado)
    li $v0, 10
    syscall

##############################################################################
# FUN��O: remove_newline
#
# Descri��o:
# - Remove o caractere de nova linha ('\n') do final da string de entrada
# - Substitui por terminador nulo
#
# Entradas:
#   buffer: string de entrada
#
# Sa�da:
#   buffer modificado in-place
##############################################################################
remove_newline:
    la $t0, buffer        # Carregar endere�o do buffer
    
loop_newline:
    # Ler caractere atual
    lb $t1, 0($t0)
    beqz $t1, end_newline  # Terminar se for nulo
    li $t2, '\n'
    beq $t1, $t2, found_newline  # Verificar se � newline
    addi $t0, $t0, 1      # Avan�ar para pr�ximo caractere
    j loop_newline
    
found_newline:
    # Substituir newline por terminador nulo
    sb $zero, 0($t0)
    
end_newline:
    jr $ra

##############################################################################
# FUN��O: parse_command
#
# Descri��o:
# - Tokeniza o comando de entrada
# - Identifica o comando e chama a fun��o correspondente
# - Gerencia tratamento de erros de sintaxe
#
# Registradores:
#   s0: endere�o do array de tokens
#   s1: quantidade de tokens
#
# Estrutura:
#   1. Tokeniza��o da entrada
#   2. Identifica��o do comando principal
#   3. Encaminhamento para handler espec�fico
#   4. Tratamento de erros
##############################################################################
parse_command:
    # Salva registradores
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)

    # Tokeniza o comando
    la $a0, buffer        # Deve ser o buffer de entrada
    la $a1, tokens        # Deve ser o array pr�-alocado
    jal tokenize
    move $s1, $v0         # Salva qtd tokens
    la $s0, tokens        # Array de tokens

    beqz $s1, parse_done  # Nenhum token?

    lw $a0, 0($s0)        # Primeiro token
    beqz $a0, parse_done  # Token vazio?
    
    # Comando: exit
    la $a1, exit_cmd
    jal strcmp
    beqz $v0, exit_program

    # Comando: ad_morador
    la $a1, msg_ad_morador
    jal strcmp
    beqz $v0, cmd_ad_morador_handler

    # Comando: rm_morador
    la $a1, msg_rm_morador
    jal strcmp
    beqz $v0, cmd_rm_morador_handler

    # Comando: ad_auto
    la $a1, msg_ad_auto
    jal strcmp
    beqz $v0, cmd_ad_auto_handler

    # Comando: rm_auto
    la $a1, msg_rm_auto
    jal strcmp
    beqz $v0, cmd_rm_auto_handler

    # Comando: limpar_ap
    la $a1, msg_limpar_ap
    jal strcmp
    beqz $v0, cmd_limpar_ap_handler

    # Comando: info_ap
    la $a1, msg_info_ap
    jal strcmp
    beqz $v0, cmd_info_ap_handler

    # Comando: info_geral
    la $a1, msg_info_geral
    jal strcmp
    beqz $v0, cmd_info_geral_handler

    # Comando: salvar
    la $a1, msg_salvar
    jal strcmp
    beqz $v0, cmd_salvar_handler

    # Comando: recarregar
    la $a1, msg_recarregar
    jal strcmp
    beqz $v0, cmd_recarregar_handler

    # Comando: formatar
    la $a1, msg_formatar
    jal strcmp
    beqz $v0, cmd_formatar_handler

    # Comando n�o reconhecido
    j invalid_cmd
    
    
cmd_ad_morador_handler:
    # Verifica quantidade de tokens (3: comando, ap, nome)
    li $t0, 3
    bne $s1, $t0, invalid_args
    
    # Obt�m �ndice do apartamento
    lw $a0, 4($s0)       # Segundo token (apartamento)
    jal get_ap_index
    bltz $v0, invalid_ap  # �ndice inv�lido
    
    # Prepara argumentos para fun��o
    move $a0, $v0        # �ndice do apartamento
    lw $a1, 8($s0)       # Terceiro token (nome)
    jal cmd_add_morador   # Chama fun��o de adi��o
    j parse_done

cmd_rm_morador_handler:
    # Verifica quantidade de tokens (3: comando, ap, nome)
    li $t0, 3
    bne $s1, $t0, invalid_args
    
    # Obt�m �ndice do apartamento
    lw $a0, 4($s0)       # Segundo token (apartamento)
    jal get_ap_index
    bltz $v0, invalid_ap  # �ndice inv�lido
    
    # Prepara argumentos para fun��o
    move $a0, $v0        # �ndice do apartamento
    lw $a1, 8($s0)       # Terceiro token (nome)
    jal cmd_rem_morador   # Chama fun��o de remo��o
    j parse_done

cmd_ad_auto_handler:
    # Verifica quantidade de tokens (5)
    li $t0, 5
    bne $s1, $t0, invalid_args
    
    # Processa apartamento
    lw $a0, 4($s0)
    jal get_ap_index
    bltz $v0, invalid_ap
    move $t1, $v0
    
    # Processa tipo
    lw $t2, 8($s0)
    lb $t2, 0($t2)   # Pega primeiro caractere
    
    # Modelo 
    lw $t3, 12($s0)  # "Fiat Uno" se for o caso
    
    # Cor 
    lw $t4, 16($s0)  # �ltimo token sempre como cor
    
    # Chama fun��o com par�metros corretos
    move $a0, $t1
    move $a1, $t2
    move $a2, $t3
    move $a3, $t4
    jal cmd_add_automovel
    
    j parse_done


cmd_rm_auto_handler:
    # Verifica quantidade de tokens (AGORA 5: comando, ap, tipo, modelo, cor)
    li $t0, 5
    bne $s1, $t0, invalid_args  # Atualizado para 5 tokens
    
    # Obt�m �ndice do apartamento
    lw $a0, 4($s0)       # Segundo token (apartamento)
    jal get_ap_index
    bltz $v0, invalid_ap
    move $t2, $v0        # Salva �ndice
    
    # Pega o PRIMEIRO CARACTERE do tipo
    lw $t3, 8($s0)       # Endere�o do token de tipo
    lb $t3, 0($t3)       # Primeiro caractere (c ou m)
    
    # Prepara argumentos para fun��o
    move $a0, $t2        # �ndice do apartamento
    move $a1, $t3        # Caractere do tipo
    lw $a2, 12($s0)      # Quarto token (modelo)
    lw $a3, 16($s0)      # Quinto token (cor)
    jal cmd_rem_automovel
    j parse_done


cmd_limpar_ap_handler:
    # Verifica quantidade de tokens (2: comando, ap)
    li $t0, 2
    bne $s1, $t0, invalid_args
    
    # Obt�m �ndice do apartamento
    lw $a0, 4($s0)       # Segundo token (apartamento)
    jal get_ap_index
    bltz $v0, invalid_ap  # �ndice inv�lido
    
    move $a0, $v0        # �ndice do apartamento
    jal cmd_clr_apartamento
    j parse_done

cmd_info_ap_handler:
    # Verifica quantidade de tokens (deve ser 2)
    # "info_ap" + argumento
    li $t0, 2
    bne $s1, $t0, invalid_args
    
    # Pega o argumento do AP
    lw $a0, 4($s0)        # Segundo token (o n�mero do AP ou "all")
    
    # Chama a fun��o principal de info_ap
    jal cmd_info_apartamento
    
    j parse_done

# Handlers para comandos sem argumentos
cmd_info_geral_handler:
cmd_salvar_handler:
cmd_recarregar_handler:
cmd_formatar_handler:
    # Verifica se tem apenas 1 token
    li $t0, 1
    bne $s1, $t0, invalid_args
    
    # Determina qual comando chamar
    lw $a0, 0($s0)        # Recarrega primeiro token
    
    # Comando: info_geral
    la $a1, msg_info_geral
    jal strcmp
    beqz $v0, call_info_geral
    
    # Comando: salvar
    la $a1, msg_salvar
    jal strcmp
    beqz $v0, call_salvar
    
    # Comando: recarregar
    la $a1, msg_recarregar
    jal strcmp
    beqz $v0, call_recarregar
    
    # Comando: formatar
    la $a1, msg_formatar
    jal strcmp
    beqz $v0, call_formatar
    
    j invalid_cmd

call_info_geral:
    jal cmd_info_geral
    j parse_done

call_salvar:
    jal cmd_salvar
    j parse_done

call_recarregar:
    jal cmd_recarregar
    j parse_done

call_formatar:
    jal cmd_formatar
    j parse_done

# Tratamento de erros
invalid_args:

invalid_cmd:
    la $a0, err_invalid_cmd
    li $v0, 4
    syscall
    j parse_done

invalid_ap:
    la $a0, err_invalid_ap
    li $v0, 4
    syscall
    j parse_done

invalid_type:
    la $a0, err_invalid_type
    li $v0, 4
    syscall
    j parse_done
    
    error_invalid_ap:
    la $a0, err_invalid_ap
    li $v0, 4
    syscall
    jr $ra

error_ap_full_res:
    la $a0, err_ap_full_res
    li $v0, 4
    syscall
    jr $ra

error_resident_not_found:
    la $a0, err_res_not_found
    li $v0, 4
    syscall
    jr $ra

exit_program:
    # Tenta salvar silenciosamente
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    
    jal cmd_salvar  # Agora usa a vers�o corrigida
    
    lw $ra, 0($sp)
    lw $a0, 4($sp)
    addi $sp, $sp, 8
    
    # Sair do programa
    li $v0, 10
    syscall

parse_done:
    # Restaura registradores e retorna
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra
    
 
##############################################################################
# FUN��O: tokenize
#
# Descri��o:
# - Divide string em tokens usando '-' como delimitador
# - Armazena ponteiros para cada token no array de tokens
# - Modifica a string original substituindo delimitadores por '\0'
#
# Entradas:
#   a0: endere�o da string de entrada
#   a1: endere�o do array de tokens
#
# Sa�da:
#   v0: n�mero de tokens encontrados
#
# Registradores:
#   t0: ponteiro para string atual
#   t1: ponteiro para array de tokens
#   t2: contador de tokens
#   t3: limite de tokens
##############################################################################
tokenize:
    # Entrada: $a0 = endere�o da string de entrada
    #          $a1 = endere�o do array para tokens
    # Sa�da:   $v0 = n�mero de tokens
    addi $sp, $sp, -20
    sw $s0, 0($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)
    sw $ra, 16($sp)      # Backup tempor�rio

    move $s0, $a0        # C�pia do input
    move $s1, $a1        # Array de tokens
    li $s2, 0            # Contador de tokens
    li $s3, 20           # M�ximo de tokens (preven��o)
    
token_loop:
    bge $s2, $s3, token_done   # Limite m�ximo
    
    # Armazena in�cio do token atual
    sw $s0, 0($s1)             
    addi $s1, $s1, 4
    addi $s2, $s2, 1

find_next:
    lb $t0, 0($s0)       # Carrega caractere atual
    beqz $t0, token_done # Fim da string?
    li $t1, '-'
    bne $t0, $t1, skip_char
    
    # Replace '-' with null terminator
    sb $zero, 0($s0)
    addi $s0, $s0, 1
    j token_loop

skip_char:
    addi $s0, $s0, 1
    j find_next

token_done:
    move $v0, $s2        # Retorna n�mero de tokens
    
    # Restaura registradores
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    lw $s2, 8($sp)
    lw $s3, 12($sp)
    lw $ra, 16($sp)
    addi $sp, $sp, 20
    jr $ra

# ==========================================
# Fun��o auxiliar: find_next_token
# $a0 = endere�o inicial
# Retorno: $v0 = tamanho do token
# ==========================================

find_next_token:
    move $t0, $a0
    li $v0, 0
    
find_loop:
    lb $t1, 0($t0)
    beqz $t1, find_done
    li $t2, '-'
    beq $t1, $t2, find_done
    addi $v0, $v0, 1
    addi $t0, $t0, 1
    j find_loop

find_done:
    jr $ra

##############################################################################
# FUN��O: str_to_int
#
# Descri��o: Converte string para inteiro com tratamento de sinal
#
# Entradas:
#   a0: endere�o da string
#
# Sa�da:
#   v0: valor convertido ou -1 para erro
##############################################################################
str_to_int:
    # Inicializa��es
    li $v0, 0              # Resultado = 0
    li $t1, 10             # Base decimal
    li $t2, 0              # Contador de d�gitos
    li $t3, 0              # Sinal (positivo)
    
    # Verifica sinal negativo
    lb $t4, 0($a0)
    bne $t4, '-', positive
    li $t3, 1              # Marca sinal negativo
    addi $a0, $a0, 1       # Avan�a para o primeiro d�gito
    
positive:
    lb $t4, 0($a0)         # Carrega primeiro caractere
    
stoi_loop:
    lb $t4, 0($a0)         # Carrega caractere atual
    beqz $t4, stoi_done    # Fim da string
    blt $t4, '0', stoi_error
    bgt $t4, '9', stoi_error
    
    # Converte d�gito
    sub $t4, $t4, '0'      # Converte char para int
    
    # resultado = resultado * 10 + d�gito
    mul $v0, $v0, $t1
    add $v0, $v0, $t4
    
    addi $a0, $a0, 1       # Pr�ximo caractere
    addi $t2, $t2, 1       # Incrementa contador de d�gitos
    j stoi_loop

stoi_error:
    # Se n�o encontrou nenhum d�gito, erro
    beqz $t2, stoi_invalid
    
    # Se encontrou pelo menos 1 d�gito, considera o que conseguiu converter
    j stoi_done

stoi_invalid:
    li $v0, -1             # Valor inv�lido

stoi_done:
    # Aplica sinal negativo se necess�rio
    beqz $t3, positive_num
    neg $v0, $v0
    
positive_num:
    jr $ra

# ======================================
# Fun��o: get_ap_index
# Descri��o: Este comando verifica qual apartamento est� sendo utilizado.
# Entrada: $a0 = string com n�mero do AP
# Sa�da: $v0 = �ndice (0-39) ou -1 se inv�lido
# ======================================
get_ap_index:
    # Salva registradores
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    
    # Converte string para inteiro
    jal str_to_int
    move $t0, $v0        # Salva o n�mero convertido em $t0
    
    # Verifica se a convers�o foi v�lida
    bltz $t0, not_found  # Usa $t0 em vez de $v0
    
    # Procura no ap_map
    la $t1, ap_map
    li $t2, 0            # Contador de �ndice
    
gapi_search_loop:
    # Carrega n�mero do AP
    lw $t3, 0($t1)
    
    # Verifica se encontrou
    beq $t3, $t0, found  # Compara com $t0 (n�mero convertido)
    
    # Pr�ximo elemento
    addi $t1, $t1, 4
    addi $t2, $t2, 1
    
    # Verifica limite (40 apartamentos)
    li $t4, 40
    blt $t2, $t4, gapi_search_loop
    
not_found:
    li $v0, -1
    j end_search

found:
    move $v0, $t2

end_search:
    # Restaura registradores
    lw $ra, 0($sp)
    lw $a0, 4($sp)
    addi $sp, $sp, 8
    jr $ra

# ======================================
# Fun��o: cmd_add_morador

# Descri��o: Adiciona um morador a um apartamento

# Comando: ad_morador-<option1>-<option2>

# Entrada:
#   $a0 = �ndice do apartamento (0-39)
#   $a1 = endere�o da string com nome do morador
# ======================================
cmd_add_morador:
    # Salva registradores na pilha
    addi $sp, $sp, -16
    sw $ra, 0($sp)      # Salva endere�o de retorno
    sw $s0, 4($sp)      # Salva $s0 (�ndice do AP)
    sw $s1, 8($sp)      # Salva $s1 (endere�o do nome)
    sw $s2, 12($sp)     # Salva $s2 (endere�o do contador de moradores)
    
    move $s0, $a0       # $s0 = �ndice do AP
    move $s1, $a1       # $s1 = nome do morador
    
    # 1. Verifica se o apartamento est� cheio (5 moradores)
    la $t0, qtd_moradores      # Carrega endere�o base dos contadores
    sll $t1, $s0, 2            # �ndice * 4 (offset em bytes)
    add $s2, $t0, $t1          # $s2 = endere�o do contador deste AP
    lw $t2, 0($s2)             # $t2 = quantidade atual de moradores
    
    li $t3, 5                  # Limite m�ximo de moradores
    bge $t2, $t3, error_full   # Se j� tem 5 moradores, erro
    
    # 2. Calcula endere�o para novo morador
    la $t0, moradores          # Endere�o base do array de moradores
    li $t1, 150                # Tamanho por AP (5 moradores * 30 bytes)
    mul $t3, $s0, $t1          # Offset do AP no array
    add $t0, $t0, $t3          # Endere�o base do AP
    
    # Calcula posi��o espec�fica: endere�o_base + (qtd_atual * 30)
    li $t1, 30                 # Tamanho por morador
    mul $t3, $t2, $t1          # Offset dentro do AP
    add $a0, $t0, $t3          # $a0 = endere�o de destino
    
    # 3. Copia nome para o array de moradores
    move $a1, $s1              # $a1 = nome (origem)
    jal strcpy                 # Copia string
    
    # 4. Atualiza contador de moradores
    lw $t2, 0($s2)             # Recupera contador atual
    addi $t2, $t2, 1           # Incrementa contador
    sw $t2, 0($s2)             # Armazena novo valor
    
    # 5. Atualiza status do apartamento (se estava vazio)
    la $t0, ap_status          # Endere�o do array de status
    add $t0, $t0, $s0          # Posi��o do AP (1 byte por elemento)
    lb $t1, 0($t0)             # Carrega status atual
    
    bnez $t1, skip_status_update # Se j� estava ocupado, pula
    li $t1, 1                  # Marca como ocupado
    sb $t1, 0($t0)             # Atualiza status
    
skip_status_update:
    # 6. Mensagem de sucesso
    la $a0, success_add_res
    li $v0, 4
    syscall
    
    j end_add_morador

error_full:
    la $a0, err_ap_full_res
    li $v0, 4
    syscall

end_add_morador:
    # Restaura registradores
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    addi $sp, $sp, 16
    jr $ra
# ======================================
# Fun��o: cmd_rem_morador
# Descri��o: Este comando Remove um morador a um apartamento especificado
# Comando: rm_morador-<option1>-<option2>
# ======================================
cmd_rem_morador:
    # Salva registradores
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # �ndice do AP
    sw $s1, 8($sp)      # Endere�o do nome
    sw $s2, 12($sp)     # Endere�o contador moradores
    sw $s3, 16($sp)     # Endere�o base moradores
    
    move $s0, $a0       # Salva �ndice do AP
    move $s1, $a1       # Salva nome do morador

    # Carrega contador de moradores
    la $t0, qtd_moradores
    sll $t1, $s0, 2
    add $s2, $t0, $t1  # $s2 = endere�o do contador
    lw $t2, 0($s2)      # $t2 = qtd atual
    
    # Verifica se h� moradores
    beqz $t2, morador_nao_encontrado

    # Configura busca
    la $s3, moradores   # Endere�o base dos moradores
    li $t3, 150         # Tamanho por AP
    mul $t3, $s0, $t3
    add $s3, $s3, $t3  # $s3 = endere�o base do AP
    
    li $t0, 0           # Contador de �ndice (i)
    li $t4, 30          # Tamanho por morador

search_loop:
    bge $t0, $t2, morador_nao_encontrado  # Fim da lista?
    
    # Calcula endere�o do morador atual
    mul $t5, $t0, $t4
    add $a0, $s3, $t5   # Endere�o do morador i
    
    # Compara nomes
    move $a1, $s1
    jal strcmp
    beqz $v0, found_morador
    
    addi $t0, $t0, 1    # Pr�ximo morador
    j search_loop

found_morador:
    # Remove morador (substitui pelo �ltimo)
    addi $t2, $t2, -1    # Decrementa contador
    sw $t2, 0($s2)       # Atualiza contador
    
    beq $t0, $t2, skip_shift  # Se era o �ltimo, n�o precisa shift
    
    # Calcula endere�o do �ltimo morador
    mul $t5, $t2, $t4
    add $a1, $s3, $t5   # Endere�o do �ltimo morador
    
    # Copia �ltimo morador para posi��o atual
    move $a0, $a0       # J� est� no endere�o atual (destino)
    jal strcpy           # Copia string

skip_shift:
    # Se apartamento ficou vazio, limpar ve�culos
    bnez $t2, success_rm_morador
    la $t0, ap_status
    add $t1, $t0, $s0
    sb $zero, 0($t1)    # Marca como vazio
    
    la $t0, tipo_veiculo
    add $t1, $t0, $s0
    sb $zero, 0($t1)    # Limpa tipo de ve�culo

success_rm_morador:
    la $a0, success_rem_res
    li $v0, 4
    syscall
    j end_rm_morador

morador_nao_encontrado:
    la $a0, err_res_not_found
    li $v0, 4
    syscall

end_rm_morador:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addi $sp, $sp, 20
    jr $ra

	
# ======================================
# Fun��o: cmd_add_automovel
# Descri��o: Este comando adiciona um autom�vel a um apartamento especificado
# Comando: ad_auto-<option1>-<option2>-<option3>-<option4>
# Par�metros:
#   $a0 = �ndice do AP (0-39)
#   $a1 = tipo ('c' para carro, 'm' para moto)
#   $a2 = modelo (string)
#   $a3 = cor (string)
# ======================================

cmd_add_automovel:
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # �ndice AP
    sw $s1, 8($sp)      # Tipo char
    sw $s2, 12($sp)     # Modelo
    sw $s3, 16($sp)     # Cor
    sw $s4, 20($sp)     # Estado tipo_veiculo
    
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    move $s3, $a3
    
    # Carregar estado atual do tipo_veiculo
    la $t0, tipo_veiculo
    add $t0, $t0, $s0
    lb $s4, 0($t0)
    
    # Verificar tipo
    li $t1, 'c'
    beq $s1, $t1, adicionar_carro
    
    li $t1, 'm'
    beq $s1, $t1, adicionar_moto
    
    j tipo_invalido

adicionar_carro:
    # Verificar se j� tem carro (bit 0)
    andi $t0, $s4, 1
    bnez $t0, ap_full_veh
    
    # Verificar se j� tem moto (bit 1 ou 2)
    andi $t0, $s4, 6   # 6 = 110 em bin�rio (moto1 e moto2)
    bnez $t0, ap_full_veh
    
    # Flag: tempor�rio = (tem carro=1) | (status atual)
    ori $s4, $s4, 1
    
    # Copiar modelo
    la $a0, modelo_carro
    li $a1, 20          # Tamanho de cada modelo
    mul $a1, $s0, $a1   # Offset = �ndice * 20
    add $a0, $a0, $a1   # Endere�o de destino
    move $a1, $s2       # Endere�o de origem (string)
    jal strcpy
    
    # Copiar cor
    la $a0, cor_carro
    li $a1, 15          # Tamanho de cada cor
    mul $a1, $s0, $a1   # Offset = �ndice * 15
    add $a0, $a0, $a1   # Endere�o de destino
    move $a1, $s3       # Endere�o de origem (string)
    jal strcpy
    
    j atualizar_estado_veiculo

adicionar_moto:
    # Verificar se tem vaga para moto
    andi $t0, $s4, 2     # Slot moto1 livre?
    beqz $t0, usar_slot1
    
    andi $t0, $s4, 4     # Slot moto2 livre?
    beqz $t0, usar_slot2
    
    j ap_full_veh         # Ambos slots ocupados

usar_slot1:
    ori $s4, $s4, 2       # Marcar slot1 ocupado
    
    # Copiar para modelo_moto1
    la $a0, modelo_moto1
    li $a1, 20
    mul $a1, $s0, $a1
    add $a0, $a0, $a1
    move $a1, $s2
    jal strcpy
    
    # Copiar para cor_moto1
    la $a0, cor_moto1
    li $a1, 15
    mul $a1, $s0, $a1
    add $a0, $a0, $a1
    move $a1, $s3
    jal strcpy
    
    j atualizar_estado_veiculo

usar_slot2:
    ori $s4, $s4, 4       # Marcar slot2 ocupado
    
    # Copiar para modelo_moto2
    la $a0, modelo_moto2
    li $a1, 20
    mul $a1, $s0, $a1
    add $a0, $a0, $a1
    move $a1, $s2
    jal strcpy
    
    # Copiar para cor_moto2
    la $a0, cor_moto2
    li $a1, 15
    mul $a1, $s0, $a1
    add $a0, $a0, $a1
    move $a1, $s3
    jal strcpy

atualizar_estado_veiculo:
    # Atualizar tipo_veiculo
    la $t0, tipo_veiculo
    add $t0, $t0, $s0
    sb $s4, 0($t0)
    
    # Mensagem de sucesso
    li $v0, 4
    la $a0, success_add_veh
    syscall
    j fim_add_auto

tipo_invalido:
    li $v0, 4
    la $a0, err_invalid_type
    syscall
    j fim_add_auto

ap_full_veh:
    li $v0, 4
    la $a0, err_ap_full_veh
    syscall

fim_add_auto:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    addi $sp, $sp, 24
    jr $ra



# ======================================
# Fun��o: cmd_rem_automovel
# Descri��o: Este comando remove um autom�vel a um apartamento especificado
# Comando: rm_auto-<option1>-<option2>-<option3>-<option4>
# Par�metros:
#   $a0 = �ndice do AP (0-39)
#   $a1 = tipo ('c' para carro, 'm' para moto)
#   $a2 = modelo (string)
#   $a3 = cor (string)
# ======================================
cmd_rem_automovel:
    
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # �ndice AP
    sw $s1, 8($sp)      # Tipo char
    sw $s2, 12($sp)     # Modelo
    sw $s3, 16($sp)     # Cor
    sw $s4, 20($sp)     # Estado tipo_veiculo
    
    move $s0, $a0
    move $s1, $a1
    move $s2, $a2
    move $s3, $a3
    
    # Carregar estado atual do tipo_veiculo
    la $t0, tipo_veiculo
    add $t0, $t0, $s0
    lb $s4, 0($t0)
    
    # Verificar tipo
    li $t1, 'c'
    beq $s1, $t1, remover_carro
    
    li $t1, 'm'
    beq $s1, $t1, remover_moto
    
    # Tipo inv�lido
    li $v0, 4
    la $a0, err_invalid_type
    syscall
    j end_rem_auto

remover_carro:
    # Verificar se existe carro
    andi $t0, $s4, 1
    beqz $t0, veiculo_nao_encontrado
    
    # Verificar modelo e cor
    la $a0, modelo_carro
    li $t1, 20
    mul $t1, $s0, $t1
    add $a0, $a0, $t1
    move $a1, $s2
    jal strcmp
    bnez $v0, veiculo_nao_encontrado
    
    la $a0, cor_carro
    li $t1, 15
    mul $t1, $s0, $t1
    add $a0, $a0, $t1
    move $a1, $s3
    jal strcmp
    bnez $v0, veiculo_nao_encontrado
    
    # Remover carro
    andi $s4, $s4, 0xFE   # Limpar bit 0
    j atualizar_estado_rem

remover_moto:
    # Verificar slot 1 (moto1)
    andi $t0, $s4, 2
    beqz $t0, verificar_moto2
    
    # Verificar moto1
    la $a0, modelo_moto1
    li $t1, 20
    mul $t1, $s0, $t1
    add $a0, $a0, $t1
    move $a1, $s2
    jal strcmp
    bnez $v0, verificar_moto2
    
    la $a0, cor_moto1
    li $t1, 15
    mul $t1, $s0, $t1
    add $a0, $a0, $t1
    move $a1, $s3
    jal strcmp
    bnez $v0, verificar_moto2
    
    # Removendo moto do slot 1
    andi $s4, $s4, 0xFD    # Limpar bit 1
    
    # Se existir moto no slot 2, move para slot 1
    andi $t0, $s4, 4
    beqz $t0, atualizar_estado_rem
    
    # Modelo: slot2 -> slot1
    la $t0, modelo_moto2
    li $t1, 20
    mul $t1, $s0, $t1
    add $a1, $t0, $t1
    
    la $t0, modelo_moto1
    add $a0, $t0, $t1
    li $a2, 20
    jal memcpy
    
    # Cor: slot2 -> slot1
    la $t0, cor_moto2
    li $t1, 15
    mul $t1, $s0, $t1
    add $a1, $t0, $t1
    
    la $t0, cor_moto1
    add $a0, $t0, $t1
    li $a2, 15
    jal memcpy
    
    # Limpa slot2
    andi $s4, $s4, 0xFB    # Limpar bit 2
    j atualizar_estado_rem

verificar_moto2:
    # Verificar slot 2 (moto2)
    andi $t0, $s4, 4
    beqz $t0, veiculo_nao_encontrado
    
    la $a0, modelo_moto2
    li $t1, 20
    mul $t1, $s0, $t1
    add $a0, $a0, $t1
    move $a1, $s2
    jal strcmp
    bnez $v0, veiculo_nao_encontrado
    
    la $a0, cor_moto2
    li $t1, 15
    mul $t1, $s0, $t1
    add $a0, $a0, $t1
    move $a1, $s3
    jal strcmp
    bnez $v0, veiculo_nao_encontrado
    
    # Removendo moto do slot 2
    andi $s4, $s4, 0xFB    # Limpar bit 2

atualizar_estado_rem:
    # Atualizar tipo_veiculo
    la $t0, tipo_veiculo
    add $t0, $t0, $s0
    sb $s4, 0($t0)
    
    # Mensagem de sucesso
    li $v0, 4
    la $a0, success_rem_veh
    syscall
    j end_rem_auto

veiculo_nao_encontrado:
    li $v0, 4
    la $a0, err_veh_not_found
    syscall

end_rem_auto:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    addi $sp, $sp, 24
    jr $ra


# ======================================
# Fun��o: cmd_clr_apartamento
# Descri��o: Este comando limpa tudo de um apartamento especificado
# Comando: limpar_ap-<option1>
# ======================================

cmd_clr_apartamento:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # Guardar �ndice AP
    
    move $s0, $a0       # $s0 = �ndice AP
    
    # Resetar ap_status
    la $t0, ap_status
    add $t0, $t0, $s0
    sb $zero, 0($t0)    # Marcar como vazio
    
    # Resetar qtd_moradores
    la $t0, qtd_moradores
    sll $t1, $s0, 2     # Offset = �ndice * 4
    add $t0, $t0, $t1
    sw $zero, 0($t0)    # Zerar contador
    
    # Resetar tipo_veiculo
    la $t0, tipo_veiculo
    add $t0, $t0, $s0
    sb $zero, 0($t0)    # Limpar ve�culos
    
    # Mensagem de sucesso
    li $v0, 4
    la $a0, success_clr_ap
    syscall
    
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra
	
	
# ======================================
# Fun��o: cmd_info_apartamento
# Descri��o: Exibe informa��es detalhadas de apartamentos
# Suporta:
#   info_ap-all: Todos APs n�o vazios
#   info_ap-XXX: AP espec�fico
# Comando: info_ap-<option1>
# ======================================

cmd_info_apartamento:
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # �ndice AP ou controle
    sw $s1, 8($sp)      # Argumento original
    sw $s2, 12($sp)     # Tempor�rio
    sw $s3, 16($sp)     # Contador
    sw $s4, 20($sp)     # N�mero AP
    
    move $s1, $a0       # Salvar argumento

    # Verificar se � "all"
    la $a1, str_all
    jal strcmp
    beqz $v0, process_all_aps

    # Processar AP espec�fico
    move $a0, $s1
    jal get_ap_index
    move $s0, $v0       # Salvar �ndice
    
    # Verificar validade do �ndice
    bltz $s0, invalid_ap_error
    li $t0, 40
    bge $s0, $t0, invalid_ap_error
    
    # Imprimir informa��es do AP
    jal print_ap_details
    j end_info_ap

process_all_aps:
    li $s3, 0           # Contador de APs
all_loop:
    li $t0, 40
    bge $s3, $t0, end_info_ap
    
     # Imprimir AP independentemente do status
    move $s0, $s3       # Usar �ndice atual
    jal print_ap_details
    
    # Ap�s imprimir cada AP, adicionar uma quebra de linha
    li $v0, 11
    li $a0, '\n'
    syscall
    
next_ap:
    addi $s3, $s3, 1
    j all_loop

invalid_ap_error:
    la $a0, err_invalid_ap
    li $v0, 4
    syscall

end_info_ap:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    addi $sp, $sp, 24
    jr $ra

# ======================================
# Fun��o: print_ap_details
# Entrada: $s0 - �ndice do AP (0-39)
# Exibe informa��es do AP
# ======================================
print_ap_details:
    addi $sp, $sp, -36
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # �ndice (preservado)
    sw $s1, 8($sp)      # Endere�os
    sw $s2, 12($sp)     # Contadores
    sw $s3, 16($sp)     # Status ve�culo
    sw $s4, 20($sp)     # Endere�o moradores
    sw $s5, 24($sp)     # Qtd moradores
    sw $s6, 28($sp)     # N�mero real do AP
    sw $s7, 32($sp)     # Tipo de ve�culo
    
    # Obter n�mero real do AP
    la $t0, ap_map
    sll $t1, $s0, 2
    add $t0, $t0, $t1
    lw $s6, 0($t0)      # $s6 = n�mero do AP
    
    # Imprimir cabe�alho
    li $v0, 4
    la $a0, str_ap
    syscall
    
    li $v0, 1
    move $a0, $s6
    syscall
    
    li $v0, 11
    li $a0, '\n'
    syscall
    
    # Verificar status do AP (seguro)
    la $t1, ap_status
    add $t1, $t1, $s0
    lb $t2, 0($t1)
    beqz $t2, ap_empty
    
    # Imprimir moradores
    la $a0, str_residents
    li $v0, 4
    syscall
    
    # Carregar contador de moradores
    la $t0, qtd_moradores
    sll $t1, $s0, 2
    add $t0, $t0, $t1
    lw $s5, 0($t0)      # $s5 = qtd moradores
    
    # Obter endere�o base dos moradores
    la $s4, moradores
    li $t1, 150         # Tamanho por AP (5*30)
    mul $t0, $s0, $t1
    add $s4, $s4, $t0
    
    # Imprimir cada morador
    li $s2, 0
print_residents:
    beq $s2, $s5, end_residents
    # Calcular posi��o do morador
    li $t1, 30
    mul $t0, $s2, $t1
    add $a0, $s4, $t0
    li $v0, 4           # Print string
    syscall
    
    # Nova linha
    li $v0, 11
    li $a0, '\n'
    syscall
    
    addi $s2, $s2, 1
    j print_residents

end_residents:
    # Verificar e imprimir ve�culos
    la $t0, tipo_veiculo
    add $t0, $t0, $s0
    lb $s7, 0($t0)      # $s7 = estado ve�culos
    
    andi $t0, $s7, 1
    beqz $t0, check_moto
    
    # Imprimir carro
    la $a0, str_car
    li $v0, 4
    syscall
    
    # Modelo
    la $a0, str_model
    syscall
    
    la $a0, modelo_carro
    li $t1, 20
    mul $t0, $s0, $t1
    add $a0, $a0, $t0
    li $v0, 4
    syscall
    
    li $a0, '\n'
    li $v0, 11
    syscall
    
    # Cor
    la $a0, str_color
    li $v0, 4
    syscall
    
    la $a0, cor_carro
    li $t1, 15
    mul $t0, $s0, $t1
    add $a0, $a0, $t0
    li $v0, 4
    syscall
    
    li $a0, '\n'
    li $v0, 11
    syscall

check_moto:
    andi $t0, $s7, 2   # Moto1
    beqz $t0, check_moto2
    
    # Cabe�alho motos (s� uma vez)
    la $a0, str_moto
    li $v0, 4
    syscall
    
    # Moto1
    la $a0, str_model
    syscall
    
    la $a0, modelo_moto1
    li $t1, 20
    mul $t0, $s0, $t1
    add $a0, $a0, $t0
    li $v0, 4
    syscall
    
    li $a0, '\n'
    li $v0, 11
    syscall
    
    la $a0, str_color
    li $v0, 4
    syscall
    
    la $a0, cor_moto1
    li $t1, 15
    mul $t0, $s0, $t1
    add $a0, $a0, $t0
    li $v0, 4
    syscall
    
    li $a0, '\n'
    li $v0, 11
    syscall

check_moto2:
    andi $t0, $s7, 4   # Moto2
    beqz $t0, end_print_ap
    
    # Moto2 (sem cabe�alho)
    la $a0, str_model
    li $v0, 4
    syscall
    
    la $a0, modelo_moto2
    li $t1, 20
    mul $t0, $s0, $t1
    add $a0, $a0, $t0
    li $v0, 4
    syscall
    
    li $a0, '\n'
    li $v0, 11
    syscall
    
    la $a0, str_color
    li $v0, 4
    syscall
    
    la $a0, cor_moto2
    li $t1, 15
    mul $t0, $s0, $t1
    add $a0, $a0, $t0
    li $v0, 4
    syscall
    
    li $a0, '\n'
    li $v0, 11
    syscall
    
    j end_print_ap

ap_empty:
    la $a0, info_ap_empty
    li $v0, 4
    syscall

end_print_ap:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    lw $s5, 24($sp)
    lw $s6, 28($sp)
    lw $s7, 32($sp)
    addi $sp, $sp, 36
    jr $ra

# ======================================
# Fun��o: cmd_info_geral
# Descri��o: Mostra panorama de ocupa��o do condom�nio
# Formato:
#   N�o vazios: X (XX%)
#   Vazios:     Y (YY%)
#   Total de apartamentos: 40
# Comando: info_geral
# ======================================
cmd_info_geral:
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # Contador de n�o vazios
    sw $s1, 8($sp)      # Contador de vazios
    sw $s2, 12($sp)     # Endere�o base de ap_status
    sw $s3, 16($sp)     # Total de apartamentos (40)
    sw $s4, 20($sp)     # Armazena porcentagens

    li $s0, 0           # Inicializa contador de n�o vazios
    li $s1, 0           # Inicializa contador de vazios
    la $s2, ap_status   # Endere�o do array de status
    li $s3, 40          # Total de apartamentos

    # Simplesmente percorre todos os APs contando o status
    li $t0, 0           # Contador de itera��o
count_loop:
    beq $t0, $s3, end_count
    
    add $t1, $s2, $t0   # Endere�o do status
    lb $t2, 0($t1)      # Carrega status
    
    beqz $t2, inc_vazio
    addi $s0, $s0, 1    # Incrementa n�o vazios
    j next_iter
inc_vazio:
    addi $s1, $s1, 1    # Incrementa vazios
next_iter:
    addi $t0, $t0, 1
    j count_loop

end_count:
    # Calcula porcentagem de n�o vazios
    mul $t0, $s0, 100   # n�o_vazios * 100
    div $s4, $t0, $s3   # s4 = (n�o_vazios * 100) / 40
    
    # Calcula porcentagem de vazios
    mul $t0, $s1, 100   # vazios * 100
    div $s5, $t0, $s3   # s5 = (vazios * 100) / 40

    # Imprime "N�o vazios"
    li $v0, 4
    la $a0, info_general_non_empty
    syscall
    
    li $v0, 1
    move $a0, $s0      # Quantidade
    syscall
    
    li $v0, 4
    la $a0, str_space
    syscall
    
    li $v0, 11
    li $a0, '('
    syscall
    
    li $v0, 1
    move $a0, $s4      # Porcentagem
    syscall
    
    li $v0, 4
    la $a0, str_percent
    syscall
    
    li $v0, 11
    li $a0, ')'         # Adiciona o par�ntese fechando
    syscall
    
    li $v0, 11
    li $a0, '\n'        # Nova linha
    syscall

    # Imprime "Vazios"
    li $v0, 4
    la $a0, info_general_empty
    syscall
    
    li $v0, 1
    move $a0, $s1      # Quantidade
    syscall
    
    li $v0, 4
    la $a0, str_space
    syscall
    
    li $v0, 11
    li $a0, '('
    syscall
    
    li $v0, 1
    move $a0, $s5      # Porcentagem
    syscall
    
    li $v0, 4
    la $a0, str_percent
    syscall
    
    li $v0, 11
    li $a0, ')'         # Adiciona o par�ntese fechando
    syscall
    
    li $v0, 11
    li $a0, '\n'        # Nova linha
    syscall

    # Total de apartamentos
    li $v0, 4
    la $a0, info_general_total
    syscall
    
    # Restaurar registradores
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    addi $sp, $sp, 24
    jr $ra



##################################################################################################
# SISTEMA DE ARMAZENAMENTO - PERSIST�NCIA - I N A C A B A D O ####################################

# ======================================
# Fun��o: cmd_salvar
# Descri��o: Este comando salva tudo em "condominio.dat"
# Comando: salvar
# ======================================

cmd_salvar:
    addi $sp, $sp, -28
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # Descritor do arquivo
    sw $s1, 8($sp)      # Contador de bytes
    sw $s2, 12($sp)     # Tempor�rio
    sw $s3, 16($sp)
    sw $s4, 20($sp)
    sw $s5, 24($sp)
    
    # Abrir arquivo com O_CREAT | O_WRONLY = 0x201 (513)
    li $v0, 13
    la $a0, filename
    li $a1, 0x201       # Corrigido para valor num�rico direto
    li $a2, 0
    syscall
    move $s0, $v0
    bltz $s0, save_err  # Erro ao abrir?
    
    
    # Salvar ap_status (40 bytes)
    li $v0, 15
    move $a0, $s0
    la $a1, ap_status
    li $a2, 40
    syscall
    move $s1, $v0       # Salvar contador de bytes escritos
    bne $s1, 40, write_err
    
    # Salvar qtd_moradores (160 bytes)
    la $a1, qtd_moradores
    li $a2, 160
    syscall
    add $s1, $s1, $v0
    bne $v0, 160, write_err
    
    # Salvar tipo_veiculo (40 bytes)
    la $a1, tipo_veiculo
    li $a2, 40
    syscall
    add $s1, $s1, $v0
    bne $v0, 40, write_err
    
    # Salvar moradores (6000 bytes)
    la $a1, moradores
    li $a2, 6000
    syscall
    add $s1, $s1, $v0
    bne $v0, 6000, write_err
    
    # Salvar modelo_carro (800 bytes)
    la $a1, modelo_carro
    li $a2, 800
    syscall
    add $s1, $s1, $v0
    bne $v0, 800, write_err
    
    # Salvar cor_carro (600 bytes)
    la $a1, cor_carro
    li $a2, 600
    syscall
    add $s1, $s1, $v0
    bne $v0, 600, write_err
    
    # Salvar modelo_moto1 (800 bytes)
    la $a1, modelo_moto1
    li $a2, 800
    syscall
    add $s1, $s1, $v0
    bne $v0, 800, write_err
    
    # Salvar cor_moto1 (600 bytes)
    la $a1, cor_moto1
    li $a2, 600
    syscall
    add $s1, $s1, $v0
    bne $v0, 600, write_err
    
    # Salvar modelo_moto2 (800 bytes)
    la $a1, modelo_moto2
    li $a2, 800
    syscall
    add $s1, $s1, $v0
    bne $v0, 800, write_err
    
    # Salvar cor_moto2 (600 bytes)
    la $a1, cor_moto2
    li $a2, 600
    syscall
    add $s1, $s1, $v0
    bne $v0, 600, write_err
    
    # Verificar tamanho total
    li $t0, 10080
    bne $s1, $t0, write_err
    
    # Fechar arquivo
    li $v0, 16
    move $a0, $s0
    syscall
    
    # Sucesso
    la $a0, success_save
    j print_save
    
save_err:
    la $a0, err_file_open
    li $v0, 4
    syscall
    j end_save
    
write_err:
    la $a0, err_file_write
    
print_save:
    li $v0, 4
    syscall
    
end_save:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    addi $sp, $sp, 12
    jr $ra

# ======================================
# Fun��o: cmd_recarregar
# Descri��o: Recarrega as informa��es salvas no arquivo externo na execu��o atual do programa. 
# Modifica��es n�o salvas ser�o perdidas e as informa��es salvas anteriormente recuperadas.  
# Comando: recarregar
# ======================================

cmd_recarregar:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Carregar com mensagens
    li $a0, 1           # Flag: imprimir mensagens
    jal load_from_file
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
# ======================================
# Fun��o: cmd_formatar
# Descri��o: Apaga todas as informa��es da execu��o atual do programa,
# deixando todos os apartamentos vazios. Este comando n�o deve salvar automaticamente no arquivo externo,
# sendo necess�rio usar posteriormente o comando �salvar� para registrar a forma��o no arquivo externo.
# Comando: formatar
# ======================================

# ======================================
# Fun��o: cmd_formatar
# Vers�o p�blica do formatar com mensagem
# ======================================
cmd_formatar:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    jal cmd_formatar_internal
    
    la $a0, success_reset
    li $v0, 4
    syscall
    
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


# ======================================
# Fun��o: clear_buffer
# Descri��o: Preenche um buffer com zeros
# Entrada: $s0 = endere�o do buffer
#          $s1 = tamanho do buffer
# ======================================
clear_buffer:
    addi $t0, $s1, 0   # Copiar contador
    move $t1, $s0      # Copiar endere�o
clear_loop:
    beqz $t0, end_clear
    sb $zero, 0($t1)
    addi $t1, $t1, 1
    addi $t0, $t0, -1
    j clear_loop
end_clear:
    jr $ra


# ======================================
# Fun��o: load_from_file (vers�o corrigida)
# Descri��o: Carrega dados do arquivo com controle de mensagens
# Entrada: $a0 = flag (0: sem mensagem, 1: com mensagem)
# Se o arquivo n�o existir, cria um novo com dados zerados
# ======================================
load_from_file:
    addi $sp, $sp, -28
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # Descritor do arquivo
    sw $s1, 8($sp)      # Bytes lidos/escritos
    sw $s2, 12($sp)     # Flag de mensagem
    sw $s3, 16($sp)     # Estado
    sw $s4, 20($sp)     # Tempor�rio
    sw $s5, 24($sp)     # Tamanho de escrita
    
    move $s2, $a0       # Salvar flag
    li $s3, 0           # Estado: carregamento normal
    
    # Tentar abrir arquivo existente
    li $v0, 13
    la $a0, filename
    li $a1, 0           # Flag: leitura
    syscall
    move $s0, $v0
    bgez $s0, process_load  # Arquivo existe

file_not_found:
    # Criar novo arquivo com dados zerados
    li $v0, 13
    la $a0, filename
    li $a1, 9           # Criar + Escrita
    syscall
    move $s0, $v0
    bltz $s0, open_error
    
    # Escrever 10080 bytes de zeros
    la $a1, empty_buffer
    li $v0, 15
    move $a0, $s0
    li $a2, 10080
    syscall
    
    # Verificar se escreveu completo
    li $t0, 10080
    bne $v0, $t0, write_error
    
    # Fechar arquivo de escrita
    li $v0, 16
    move $a0, $s0
    syscall
    
    # Reabrir para leitura
    li $v0, 13
    la $a0, filename
    li $a1, 0
    syscall
    move $s0, $v0
    bltz $s0, open_error
    
    li $s3, 1           # Estado: novo arquivo criado

process_load:
    # Formatar dados internamente
    jal cmd_formatar_internal
    
    # Carregar ap_status (40 bytes)
    li $v0, 14
    move $a0, $s0
    la $a1, ap_status
    li $a2, 40
    syscall
    move $s1, $v0
    bne $s1, 40, read_error
    
    # Carregar qtd_moradores (160 bytes)
    la $a1, qtd_moradores
    li $a2, 160
    syscall
    add $s1, $s1, $v0
    bne $v0, 160, read_error
    
    # Carregar tipo_veiculo (40 bytes)
    la $a1, tipo_veiculo
    li $a2, 40
    syscall
    add $s1, $s1, $v0
    bne $v0, 40, read_error
    
    # Carregar moradores (6000 bytes)
    la $a1, moradores
    li $a2, 6000
    syscall
    add $s1, $s1, $v0
    bne $v0, 6000, read_error
    
    # Carregar modelo_carro (800 bytes)
    la $a1, modelo_carro
    li $a2, 800
    syscall
    add $s1, $s1, $v0
    bne $v0, 800, read_error
    
    # Carregar cor_carro (600 bytes)
    la $a1, cor_carro
    li $a2, 600
    syscall
    add $s1, $s1, $v0
    bne $v0, 600, read_error
    
    # Carregar modelo_moto1 (800 bytes)
    la $a1, modelo_moto1
    li $a2, 800
    syscall
    add $s1, $s1, $v0
    bne $v0, 800, read_error
    
    # Carregar cor_moto1 (600 bytes)
    la $a1, cor_moto1
    li $a2, 600
    syscall
    add $s1, $s1, $v0
    bne $v0, 600, read_error
    
    # Carregar modelo_moto2 (800 bytes)
    la $a1, modelo_moto2
    li $a2, 800
    syscall
    add $s1, $s1, $v0
    bne $v0, 800, read_error
    
    # Carregar cor_moto2 (600 bytes)
    la $a1, cor_moto2
    li $a2, 600
    syscall
    add $s1, $s1, $v0
    bne $v0, 600, read_error
    
    # Fechar arquivo
    li $v0, 16
    move $a0, $s0
    syscall
    
    # Verificar estado para mensagem
    beqz $s2, skip_msg  # Se flag=0, n�o mostrar mensagem
    
    # Mensagem baseada no estado
    beq $s3, 1, new_file_msg
    la $a0, success_load
    j print_msg
new_file_msg:
    la $a0, msg_created
    j print_msg

open_error:
    la $a0, err_file_open
    j handle_error

write_error:
    # Fechar arquivo se estiver aberto
    move $a0, $s0
    li $v0, 16
    syscall
    la $a0, err_file_write
    j handle_error

read_error:
    # Fechar arquivo
    move $a0, $s0
    li $v0, 16
    syscall
    la $a0, err_file_read

handle_error:
    beqz $s2, end_load  # Se flag=0, silenciar erro
    li $v0, 4
    syscall
    j end_load

print_msg:
    li $v0, 4
    syscall

skip_msg:
end_load:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    lw $s5, 24($sp)
    addi $sp, $sp, 28
    jr $ra

# ======================================
# Fun��o: cmd_formatar_internal
# Descri��o: Formata dados sem imprimir mensagem
# ======================================
cmd_formatar_internal:
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    
    # Inicializa ap_status com zeros
    la $s0, ap_status
    li $s1, 40
initialize_status:
    beqz $s1, next_1
    sb $zero, 0($s0)
    addi $s0, $s0, 1
    addi $s1, $s1, -1
    j initialize_status

next_1:
    # Inicializa qtd_moradores com zeros
    la $s0, qtd_moradores
    li $s1, 10          # 40 apartamentos * 4 bytes = 160 bytes (40 words)
init_qtd_loop:
    beqz $s1, next_2
    sw $zero, 0($s0)
    addi $s0, $s0, 4
    addi $s1, $s1, -1
    j init_qtd_loop

next_2:
    # Inicializa tipo_veiculo com zeros
    la $s0, tipo_veiculo
    li $s1, 40
init_veiculo:
    beqz $s1, next_3
    sb $zero, 0($s0)
    addi $s0, $s0, 1
    addi $s1, $s1, -1
    j init_veiculo

next_3:
    # Inicializa arrays de strings
    la $s0, moradores
    li $s1, 6000
init_moradores:
    beqz $s1, next_4
    sb $zero, 0($s0)
    addi $s0, $s0, 1
    addi $s1, $s1, -1
    j init_moradores

next_4:
    la $s0, modelo_carro
    li $s1, 800
init_modelo_carro:
    beqz $s1, next_5
    sb $zero, 0($s0)
    addi $s0, $s0, 1
    addi $s1, $s1, -1
    j init_modelo_carro

next_5:
    la $s0, cor_carro
    li $s1, 600
init_cor_carro:
    beqz $s1, next_6
    sb $zero, 0($s0)
    addi $s0, $s0, 1
    addi $s1, $s1, -1
    j init_cor_carro

next_6:
    la $s0, modelo_moto1
    li $s1, 800
init_modelo_moto1:
    beqz $s1, next_7
    sb $zero, 0($s0)
    addi $s0, $s0, 1
    addi $s1, $s1, -1
    j init_modelo_moto1

next_7:
    la $s0, cor_moto1
    li $s1, 600
init_cor_moto1:
    beqz $s1, next_8
    sb $zero, 0($s0)
    addi $s0, $s0, 1
    addi $s1, $s1, -1
    j init_cor_moto1

next_8:
    la $s0, modelo_moto2
    li $s1, 800
init_modelo_moto2:
    beqz $s1, next_9
    sb $zero, 0($s0)
    addi $s0, $s0, 1
    addi $s1, $s1, -1
    j init_modelo_moto2

next_9:
    la $s0, cor_moto2
    li $s1, 600
init_cor_moto2:
    beqz $s1, exit_init
    sb $zero, 0($s0)
    addi $s0, $s0, 1
    addi $s1, $s1, -1
    j init_cor_moto2

exit_init:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    addi $sp, $sp, 16
    jr $ra


# ======================================
# Fun��es de String (da Lista de Exerc�cio)
# ======================================

# ======================================
# Fun��o: strcpy = String Copy
# Descri��o: Copia string de origem para destino
# Par�metros:
#   $a0 - endere�o do destino
#   $a1 - endere�o da origem
# Retorno:
#   $v0 - endere�o original do destino
# ======================================
strcpy:
    # $a0 = destino, $a1 = origem
    move $t0, $a0
    move $t1, $a1
strcpy_loop:
    lb $t2, 0($t1)
    beqz $t2, strcpy_done
    sb $t2, 0($t0)
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j strcpy_loop
strcpy_done:
    sb $zero, 0($t0)  # Garante terminador nulo
    jr $ra

# ======================================
# Fun��o: memcpy = Memory Copy
# Descri��o: Copia blocos de mem�ria
# Par�metros:
#   $a0 - endere�o do destino
#   $a1 - endere�o da origem
#   $a2 - n�mero de bytes a copiar
# Retorno:
#   $v0 - endere�o original do destino
# ======================================
memcpy:
    move $v0, $a0       # Salva endere�o original do destino
    move $t2, $a2       # Configura contador de bytes
    
memcpy_loop:
    beqz $t2, memcpy_done # Se contador = 0, termina
    lb $t0, 0($a1)      # Carrega byte da origem
    sb $t0, 0($a0)      # Armazena byte no destino
    addi $a0, $a0, 1    # Avan�a destino
    addi $a1, $a1, 1    # Avan�a origem
    addi $t2, $t2, -1   # Decrementa contador
    j memcpy_loop       # Repete o loop
    
memcpy_done:
    jr $ra              # Retorna ao chamador

# ======================================
# Fun��o: strcmp = String Comparator
# Descri��o: Compara duas strings
# Par�metros:
#   $a0 - endere�o da primeira string
#   $a1 - endere�o da segunda string
# Retorno:
#   $v0 - 0 (igual), negativo (str1 < str2), positivo (str1 > str2)
# ======================================

strcmp:
    # Entrada: $a0, $a1 - endere�os das strings
    # Sa�da: $v0 - 0 (iguais), negativo (str1 < str2), positivo (str1 > str2)
    move $t0, $a0
    move $t1, $a1
    
strcmp_loop:
    # Carrega bytes atuais
    lb $t2, 0($t0)         # Carrega byte da str1
    lb $t3, 0($t1)         # Carrega byte da str2
    
    # Verifica final da str1
    beqz $t2, strcmp_check  # Se str1 terminou
    
    # Verifica se terminou somente a str2
    beqz $t3, strcmp_finish
    
    # Compara caracteres
    bne $t2, $t3, strcmp_diff  # Se caracteres diferentes
    
    # Avan�a para o pr�ximo caractere
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j strcmp_loop

strcmp_check:
    bnez $t3, strcmp_finish  # Se str1 terminou mas str2 n�o
    li $v0, 0                # Ambas terminaram, strings iguais
    jr $ra

strcmp_finish:
    # Calcula diferen�a entre os caracteres
    sub $v0, $t2, $t3
    jr $ra

strcmp_diff:
    sub $v0, $t2, $t3
    jr $ra


# ======================================
# Fun��o: strncmp = String N Comparator
# Descri��o: Compara at� n caracteres de duas strings
# Par�metros:
#   $a0 - endere�o da primeira string
#   $a1 - endere�o da segunda string
#   $a2 - n�mero m�ximo de caracteres a comparar
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
    addi $a0, $a0, 1    # Avan�a str1
    addi $a1, $a1, 1    # Avan�a str2
    addi $a2, $a2, -1   # Decrementa contador
    j strncmp_loop      # Continua compara��o
    
strncmp_check:
    beqz $t1, strncmp_done # Se str2 tamb�m terminou, s�o iguais
strncmp_neg:
    li $v0, -1          # Retorna -1
    jr $ra              
strncmp_pos:
    li $v0, 1           # Retorna 1
    jr $ra              
strncmp_diff:
    sub $v0, $t0, $t1   # Calcula diferen�a ASCII
strncmp_done:
    jr $ra              # Retorna ao chamador

# ======================================
# Fun��o: strcat = String Concatenator
# Descri��o: Concatena duas strings
# Par�metros:
#   $a0 - endere�o do destino
#   $a1 - endere�o da origem
# Retorno:
#   $v0 - endere�o original do destino
# ======================================
strcat:
    move $t0, $a0       # Salva endere�o original do destino
    
strcat_find_end:
    lb $t1, 0($t0)      # Carrega byte do destino
    beqz $t1, strcat_copy # Se NULL, inicia c�pia
    addi $t0, $t0, 1    # Avan�a no destino
    j strcat_find_end   # Continua procurando fim
    
strcat_copy:
    lb $t1, 0($a1)      # Carrega byte da origem
    sb $t1, 0($t0)      # Armazena no destino
    beqz $t1, strcat_done # Se NULL, termina
    addi $t0, $t0, 1    # Avan�a destino
    addi $a1, $a1, 1    # Avan�a origem
    j strcat_copy       # Continua c�pia
    
strcat_done:
    move $v0, $a0       # Retorna endere�o original
    jr $ra              # Retorna ao chamador