##############################################################################
# Grupo: Adriano Lucas, Emmanuel Nascimento, Renato Barbosa e Vinícius Marques
# Atividade: Projeto 1VA
# Disciplina: Arquitetura e Organização de Computadores
# Semestre Letivo: 4o
# 
# Descrição:
# Sistema de gerenciamento de condomínio com shell interativo para cadastro:
# - Moradores (até 5 por apartamento)
# - Veículos (1 carro ou 2 motos por apartamento)
# - Comandos para adicionar, remover, visualizar e limpar dados
# - Persistência em arquivo binário
#
# Principais componentes:
# 1. Parser de comandos com tokenização de strings
# 2. Mapemento de apartamentos (40 unidades)
# 3. Armazenamento eficiente em arrays pré-alocados
# 4. Operações CRUD para moradores e veículos
# 5. Sistema de arquivos com auto-criação e recuperação de erros
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
qtd_moradores: .space 160     # 40 APs × 4 bytes
moradores:     .space 6000    # 40 APs × 5 moradores × 30 caracteres

tipo_veiculo:  .space 40      # Estado veículos (1 bit carro + 2 bits motos)
modelo_carro:  .space 800     # 40 APs × 20 bytes
cor_carro:     .space 600     # 40 APs × 15 bytes
modelo_moto1:  .space 800     # 40 APs × 20 bytes
cor_moto1:     .space 600     # 40 APs × 15 bytes
modelo_moto2:  .space 800     # 40 APs × 20 bytes
cor_moto2:     .space 600     # 40 APs × 15 bytes

### COMANDOS E STRINGS DE SAÍDA ##############################################
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

# Cabeçalhos para informações
str_ap:        .asciiz "AP: "
str_residents: .asciiz "Moradores:\n"
str_car:       .asciiz "Carro:\n"
str_moto:      .asciiz "Moto:\n"
str_model:     .asciiz "\tModelo: "
str_color:     .asciiz "\tCor: "

# Identificadores de tipo de veículo
str_car_cmd:   .asciiz "c"
str_moto_cmd:  .asciiz "m"

### ARQUIVO ##################################################################
filename:      .asciiz "condominio.dat"
empty_buffer:  .space 10080    # Tamanho total dos dados (40×1 + 40×4 + ...)

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

# Mensagens de informação
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
# Descrição:
# - Inicializa o sistema carregando dados de arquivo
# - Exibe prompt interativo para comandos
# - Processa comandos em loop até receber 'exit'
# - Ao sair, salva automaticamente o estado
##############################################################################
main:
    # Carregamento inicial silencioso dos dados
    li $a0, 0
    jal load_from_file
    
main_loop:
    # Exibir prompt para usuário
    li $v0, 4
    la $a0, banner
    syscall

    # Ler entrada do usuário
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

    # Ponto de saída (nunca alcançado)
    li $v0, 10
    syscall

##############################################################################
# FUNÇÃO: remove_newline
#
# Descrição:
# - Remove o caractere de nova linha ('\n') do final da string de entrada
# - Substitui por terminador nulo
#
# Entradas:
#   buffer: string de entrada
#
# Saída:
#   buffer modificado in-place
##############################################################################
remove_newline:
    la $t0, buffer        # Carregar endereço do buffer
    
loop_newline:
    # Ler caractere atual
    lb $t1, 0($t0)
    beqz $t1, end_newline  # Terminar se for nulo
    li $t2, '\n'
    beq $t1, $t2, found_newline  # Verificar se é newline
    addi $t0, $t0, 1      # Avançar para próximo caractere
    j loop_newline
    
found_newline:
    # Substituir newline por terminador nulo
    sb $zero, 0($t0)
    
end_newline:
    jr $ra

##############################################################################
# FUNÇÃO: parse_command
#
# Descrição:
# - Tokeniza o comando de entrada
# - Identifica o comando e chama a função correspondente
# - Gerencia tratamento de erros de sintaxe
#
# Registradores:
#   s0: endereço do array de tokens
#   s1: quantidade de tokens
#
# Estrutura:
#   1. Tokenização da entrada
#   2. Identificação do comando principal
#   3. Encaminhamento para handler específico
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
    la $a1, tokens        # Deve ser o array pré-alocado
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

    # Comando não reconhecido
    j invalid_cmd
    
    
cmd_ad_morador_handler:
    # Verifica quantidade de tokens (3: comando, ap, nome)
    li $t0, 3
    bne $s1, $t0, invalid_args
    
    # Obtém índice do apartamento
    lw $a0, 4($s0)       # Segundo token (apartamento)
    jal get_ap_index
    bltz $v0, invalid_ap  # Índice inválido
    
    # Prepara argumentos para função
    move $a0, $v0        # Índice do apartamento
    lw $a1, 8($s0)       # Terceiro token (nome)
    jal cmd_add_morador   # Chama função de adição
    j parse_done

cmd_rm_morador_handler:
    # Verifica quantidade de tokens (3: comando, ap, nome)
    li $t0, 3
    bne $s1, $t0, invalid_args
    
    # Obtém índice do apartamento
    lw $a0, 4($s0)       # Segundo token (apartamento)
    jal get_ap_index
    bltz $v0, invalid_ap  # Índice inválido
    
    # Prepara argumentos para função
    move $a0, $v0        # Índice do apartamento
    lw $a1, 8($s0)       # Terceiro token (nome)
    jal cmd_rem_morador   # Chama função de remoção
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
    lw $t4, 16($s0)  # Último token sempre como cor
    
    # Chama função com parâmetros corretos
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
    
    # Obtém índice do apartamento
    lw $a0, 4($s0)       # Segundo token (apartamento)
    jal get_ap_index
    bltz $v0, invalid_ap
    move $t2, $v0        # Salva índice
    
    # Pega o PRIMEIRO CARACTERE do tipo
    lw $t3, 8($s0)       # Endereço do token de tipo
    lb $t3, 0($t3)       # Primeiro caractere (c ou m)
    
    # Prepara argumentos para função
    move $a0, $t2        # Índice do apartamento
    move $a1, $t3        # Caractere do tipo
    lw $a2, 12($s0)      # Quarto token (modelo)
    lw $a3, 16($s0)      # Quinto token (cor)
    jal cmd_rem_automovel
    j parse_done


cmd_limpar_ap_handler:
    # Verifica quantidade de tokens (2: comando, ap)
    li $t0, 2
    bne $s1, $t0, invalid_args
    
    # Obtém índice do apartamento
    lw $a0, 4($s0)       # Segundo token (apartamento)
    jal get_ap_index
    bltz $v0, invalid_ap  # Índice inválido
    
    move $a0, $v0        # Índice do apartamento
    jal cmd_clr_apartamento
    j parse_done

cmd_info_ap_handler:
    # Verifica quantidade de tokens (deve ser 2)
    # "info_ap" + argumento
    li $t0, 2
    bne $s1, $t0, invalid_args
    
    # Pega o argumento do AP
    lw $a0, 4($s0)        # Segundo token (o número do AP ou "all")
    
    # Chama a função principal de info_ap
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
    
    jal cmd_salvar  # Agora usa a versão corrigida
    
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
# FUNÇÃO: tokenize
#
# Descrição:
# - Divide string em tokens usando '-' como delimitador
# - Armazena ponteiros para cada token no array de tokens
# - Modifica a string original substituindo delimitadores por '\0'
#
# Entradas:
#   a0: endereço da string de entrada
#   a1: endereço do array de tokens
#
# Saída:
#   v0: número de tokens encontrados
#
# Registradores:
#   t0: ponteiro para string atual
#   t1: ponteiro para array de tokens
#   t2: contador de tokens
#   t3: limite de tokens
##############################################################################
tokenize:
    # Entrada: $a0 = endereço da string de entrada
    #          $a1 = endereço do array para tokens
    # Saída:   $v0 = número de tokens
    addi $sp, $sp, -20
    sw $s0, 0($sp)
    sw $s1, 4($sp)
    sw $s2, 8($sp)
    sw $s3, 12($sp)
    sw $ra, 16($sp)      # Backup temporário

    move $s0, $a0        # Cópia do input
    move $s1, $a1        # Array de tokens
    li $s2, 0            # Contador de tokens
    li $s3, 20           # Máximo de tokens (prevenção)
    
token_loop:
    bge $s2, $s3, token_done   # Limite máximo
    
    # Armazena início do token atual
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
    move $v0, $s2        # Retorna número de tokens
    
    # Restaura registradores
    lw $s0, 0($sp)
    lw $s1, 4($sp)
    lw $s2, 8($sp)
    lw $s3, 12($sp)
    lw $ra, 16($sp)
    addi $sp, $sp, 20
    jr $ra

# ==========================================
# Função auxiliar: find_next_token
# $a0 = endereço inicial
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
# FUNÇÃO: str_to_int
#
# Descrição: Converte string para inteiro com tratamento de sinal
#
# Entradas:
#   a0: endereço da string
#
# Saída:
#   v0: valor convertido ou -1 para erro
##############################################################################
str_to_int:
    # Inicializações
    li $v0, 0              # Resultado = 0
    li $t1, 10             # Base decimal
    li $t2, 0              # Contador de dígitos
    li $t3, 0              # Sinal (positivo)
    
    # Verifica sinal negativo
    lb $t4, 0($a0)
    bne $t4, '-', positive
    li $t3, 1              # Marca sinal negativo
    addi $a0, $a0, 1       # Avança para o primeiro dígito
    
positive:
    lb $t4, 0($a0)         # Carrega primeiro caractere
    
stoi_loop:
    lb $t4, 0($a0)         # Carrega caractere atual
    beqz $t4, stoi_done    # Fim da string
    blt $t4, '0', stoi_error
    bgt $t4, '9', stoi_error
    
    # Converte dígito
    sub $t4, $t4, '0'      # Converte char para int
    
    # resultado = resultado * 10 + dígito
    mul $v0, $v0, $t1
    add $v0, $v0, $t4
    
    addi $a0, $a0, 1       # Próximo caractere
    addi $t2, $t2, 1       # Incrementa contador de dígitos
    j stoi_loop

stoi_error:
    # Se não encontrou nenhum dígito, erro
    beqz $t2, stoi_invalid
    
    # Se encontrou pelo menos 1 dígito, considera o que conseguiu converter
    j stoi_done

stoi_invalid:
    li $v0, -1             # Valor inválido

stoi_done:
    # Aplica sinal negativo se necessário
    beqz $t3, positive_num
    neg $v0, $v0
    
positive_num:
    jr $ra

# ======================================
# Função: get_ap_index
# Descrição: Este comando verifica qual apartamento está sendo utilizado.
# Entrada: $a0 = string com número do AP
# Saída: $v0 = índice (0-39) ou -1 se inválido
# ======================================
get_ap_index:
    # Salva registradores
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $a0, 4($sp)
    
    # Converte string para inteiro
    jal str_to_int
    move $t0, $v0        # Salva o número convertido em $t0
    
    # Verifica se a conversão foi válida
    bltz $t0, not_found  # Usa $t0 em vez de $v0
    
    # Procura no ap_map
    la $t1, ap_map
    li $t2, 0            # Contador de índice
    
gapi_search_loop:
    # Carrega número do AP
    lw $t3, 0($t1)
    
    # Verifica se encontrou
    beq $t3, $t0, found  # Compara com $t0 (número convertido)
    
    # Próximo elemento
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
# Função: cmd_add_morador

# Descrição: Adiciona um morador a um apartamento

# Comando: ad_morador-<option1>-<option2>

# Entrada:
#   $a0 = índice do apartamento (0-39)
#   $a1 = endereço da string com nome do morador
# ======================================
cmd_add_morador:
    # Salva registradores na pilha
    addi $sp, $sp, -16
    sw $ra, 0($sp)      # Salva endereço de retorno
    sw $s0, 4($sp)      # Salva $s0 (índice do AP)
    sw $s1, 8($sp)      # Salva $s1 (endereço do nome)
    sw $s2, 12($sp)     # Salva $s2 (endereço do contador de moradores)
    
    move $s0, $a0       # $s0 = índice do AP
    move $s1, $a1       # $s1 = nome do morador
    
    # 1. Verifica se o apartamento está cheio (5 moradores)
    la $t0, qtd_moradores      # Carrega endereço base dos contadores
    sll $t1, $s0, 2            # Índice * 4 (offset em bytes)
    add $s2, $t0, $t1          # $s2 = endereço do contador deste AP
    lw $t2, 0($s2)             # $t2 = quantidade atual de moradores
    
    li $t3, 5                  # Limite máximo de moradores
    bge $t2, $t3, error_full   # Se já tem 5 moradores, erro
    
    # 2. Calcula endereço para novo morador
    la $t0, moradores          # Endereço base do array de moradores
    li $t1, 150                # Tamanho por AP (5 moradores * 30 bytes)
    mul $t3, $s0, $t1          # Offset do AP no array
    add $t0, $t0, $t3          # Endereço base do AP
    
    # Calcula posição específica: endereço_base + (qtd_atual * 30)
    li $t1, 30                 # Tamanho por morador
    mul $t3, $t2, $t1          # Offset dentro do AP
    add $a0, $t0, $t3          # $a0 = endereço de destino
    
    # 3. Copia nome para o array de moradores
    move $a1, $s1              # $a1 = nome (origem)
    jal strcpy                 # Copia string
    
    # 4. Atualiza contador de moradores
    lw $t2, 0($s2)             # Recupera contador atual
    addi $t2, $t2, 1           # Incrementa contador
    sw $t2, 0($s2)             # Armazena novo valor
    
    # 5. Atualiza status do apartamento (se estava vazio)
    la $t0, ap_status          # Endereço do array de status
    add $t0, $t0, $s0          # Posição do AP (1 byte por elemento)
    lb $t1, 0($t0)             # Carrega status atual
    
    bnez $t1, skip_status_update # Se já estava ocupado, pula
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
# Função: cmd_rem_morador
# Descrição: Este comando Remove um morador a um apartamento especificado
# Comando: rm_morador-<option1>-<option2>
# ======================================
cmd_rem_morador:
    # Salva registradores
    addi $sp, $sp, -20
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # Índice do AP
    sw $s1, 8($sp)      # Endereço do nome
    sw $s2, 12($sp)     # Endereço contador moradores
    sw $s3, 16($sp)     # Endereço base moradores
    
    move $s0, $a0       # Salva índice do AP
    move $s1, $a1       # Salva nome do morador

    # Carrega contador de moradores
    la $t0, qtd_moradores
    sll $t1, $s0, 2
    add $s2, $t0, $t1  # $s2 = endereço do contador
    lw $t2, 0($s2)      # $t2 = qtd atual
    
    # Verifica se há moradores
    beqz $t2, morador_nao_encontrado

    # Configura busca
    la $s3, moradores   # Endereço base dos moradores
    li $t3, 150         # Tamanho por AP
    mul $t3, $s0, $t3
    add $s3, $s3, $t3  # $s3 = endereço base do AP
    
    li $t0, 0           # Contador de índice (i)
    li $t4, 30          # Tamanho por morador

search_loop:
    bge $t0, $t2, morador_nao_encontrado  # Fim da lista?
    
    # Calcula endereço do morador atual
    mul $t5, $t0, $t4
    add $a0, $s3, $t5   # Endereço do morador i
    
    # Compara nomes
    move $a1, $s1
    jal strcmp
    beqz $v0, found_morador
    
    addi $t0, $t0, 1    # Próximo morador
    j search_loop

found_morador:
    # Remove morador (substitui pelo último)
    addi $t2, $t2, -1    # Decrementa contador
    sw $t2, 0($s2)       # Atualiza contador
    
    beq $t0, $t2, skip_shift  # Se era o último, não precisa shift
    
    # Calcula endereço do último morador
    mul $t5, $t2, $t4
    add $a1, $s3, $t5   # Endereço do último morador
    
    # Copia último morador para posição atual
    move $a0, $a0       # Já está no endereço atual (destino)
    jal strcpy           # Copia string

skip_shift:
    # Se apartamento ficou vazio, limpar veículos
    bnez $t2, success_rm_morador
    la $t0, ap_status
    add $t1, $t0, $s0
    sb $zero, 0($t1)    # Marca como vazio
    
    la $t0, tipo_veiculo
    add $t1, $t0, $s0
    sb $zero, 0($t1)    # Limpa tipo de veículo

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
# Função: cmd_add_automovel
# Descrição: Este comando adiciona um automóvel a um apartamento especificado
# Comando: ad_auto-<option1>-<option2>-<option3>-<option4>
# Parâmetros:
#   $a0 = índice do AP (0-39)
#   $a1 = tipo ('c' para carro, 'm' para moto)
#   $a2 = modelo (string)
#   $a3 = cor (string)
# ======================================

cmd_add_automovel:
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # Índice AP
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
    # Verificar se já tem carro (bit 0)
    andi $t0, $s4, 1
    bnez $t0, ap_full_veh
    
    # Verificar se já tem moto (bit 1 ou 2)
    andi $t0, $s4, 6   # 6 = 110 em binário (moto1 e moto2)
    bnez $t0, ap_full_veh
    
    # Flag: temporário = (tem carro=1) | (status atual)
    ori $s4, $s4, 1
    
    # Copiar modelo
    la $a0, modelo_carro
    li $a1, 20          # Tamanho de cada modelo
    mul $a1, $s0, $a1   # Offset = índice * 20
    add $a0, $a0, $a1   # Endereço de destino
    move $a1, $s2       # Endereço de origem (string)
    jal strcpy
    
    # Copiar cor
    la $a0, cor_carro
    li $a1, 15          # Tamanho de cada cor
    mul $a1, $s0, $a1   # Offset = índice * 15
    add $a0, $a0, $a1   # Endereço de destino
    move $a1, $s3       # Endereço de origem (string)
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
# Função: cmd_rem_automovel
# Descrição: Este comando remove um automóvel a um apartamento especificado
# Comando: rm_auto-<option1>-<option2>-<option3>-<option4>
# Parâmetros:
#   $a0 = índice do AP (0-39)
#   $a1 = tipo ('c' para carro, 'm' para moto)
#   $a2 = modelo (string)
#   $a3 = cor (string)
# ======================================
cmd_rem_automovel:
    
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # Índice AP
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
    
    # Tipo inválido
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
# Função: cmd_clr_apartamento
# Descrição: Este comando limpa tudo de um apartamento especificado
# Comando: limpar_ap-<option1>
# ======================================

cmd_clr_apartamento:
    addi $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # Guardar índice AP
    
    move $s0, $a0       # $s0 = índice AP
    
    # Resetar ap_status
    la $t0, ap_status
    add $t0, $t0, $s0
    sb $zero, 0($t0)    # Marcar como vazio
    
    # Resetar qtd_moradores
    la $t0, qtd_moradores
    sll $t1, $s0, 2     # Offset = índice * 4
    add $t0, $t0, $t1
    sw $zero, 0($t0)    # Zerar contador
    
    # Resetar tipo_veiculo
    la $t0, tipo_veiculo
    add $t0, $t0, $s0
    sb $zero, 0($t0)    # Limpar veículos
    
    # Mensagem de sucesso
    li $v0, 4
    la $a0, success_clr_ap
    syscall
    
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addi $sp, $sp, 8
    jr $ra
	
	
# ======================================
# Função: cmd_info_apartamento
# Descrição: Exibe informações detalhadas de apartamentos
# Suporta:
#   info_ap-all: Todos APs não vazios
#   info_ap-XXX: AP específico
# Comando: info_ap-<option1>
# ======================================

cmd_info_apartamento:
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # Índice AP ou controle
    sw $s1, 8($sp)      # Argumento original
    sw $s2, 12($sp)     # Temporário
    sw $s3, 16($sp)     # Contador
    sw $s4, 20($sp)     # Número AP
    
    move $s1, $a0       # Salvar argumento

    # Verificar se é "all"
    la $a1, str_all
    jal strcmp
    beqz $v0, process_all_aps

    # Processar AP específico
    move $a0, $s1
    jal get_ap_index
    move $s0, $v0       # Salvar índice
    
    # Verificar validade do índice
    bltz $s0, invalid_ap_error
    li $t0, 40
    bge $s0, $t0, invalid_ap_error
    
    # Imprimir informações do AP
    jal print_ap_details
    j end_info_ap

process_all_aps:
    li $s3, 0           # Contador de APs
all_loop:
    li $t0, 40
    bge $s3, $t0, end_info_ap
    
     # Imprimir AP independentemente do status
    move $s0, $s3       # Usar índice atual
    jal print_ap_details
    
    # Após imprimir cada AP, adicionar uma quebra de linha
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
# Função: print_ap_details
# Entrada: $s0 - índice do AP (0-39)
# Exibe informações do AP
# ======================================
print_ap_details:
    addi $sp, $sp, -36
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # Índice (preservado)
    sw $s1, 8($sp)      # Endereços
    sw $s2, 12($sp)     # Contadores
    sw $s3, 16($sp)     # Status veículo
    sw $s4, 20($sp)     # Endereço moradores
    sw $s5, 24($sp)     # Qtd moradores
    sw $s6, 28($sp)     # Número real do AP
    sw $s7, 32($sp)     # Tipo de veículo
    
    # Obter número real do AP
    la $t0, ap_map
    sll $t1, $s0, 2
    add $t0, $t0, $t1
    lw $s6, 0($t0)      # $s6 = número do AP
    
    # Imprimir cabeçalho
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
    
    # Obter endereço base dos moradores
    la $s4, moradores
    li $t1, 150         # Tamanho por AP (5*30)
    mul $t0, $s0, $t1
    add $s4, $s4, $t0
    
    # Imprimir cada morador
    li $s2, 0
print_residents:
    beq $s2, $s5, end_residents
    # Calcular posição do morador
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
    # Verificar e imprimir veículos
    la $t0, tipo_veiculo
    add $t0, $t0, $s0
    lb $s7, 0($t0)      # $s7 = estado veículos
    
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
    
    # Cabeçalho motos (só uma vez)
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
    
    # Moto2 (sem cabeçalho)
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
# Função: cmd_info_geral
# Descrição: Mostra panorama de ocupação do condomínio
# Formato:
#   Não vazios: X (XX%)
#   Vazios:     Y (YY%)
#   Total de apartamentos: 40
# Comando: info_geral
# ======================================
cmd_info_geral:
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # Contador de não vazios
    sw $s1, 8($sp)      # Contador de vazios
    sw $s2, 12($sp)     # Endereço base de ap_status
    sw $s3, 16($sp)     # Total de apartamentos (40)
    sw $s4, 20($sp)     # Armazena porcentagens

    li $s0, 0           # Inicializa contador de não vazios
    li $s1, 0           # Inicializa contador de vazios
    la $s2, ap_status   # Endereço do array de status
    li $s3, 40          # Total de apartamentos

    # Simplesmente percorre todos os APs contando o status
    li $t0, 0           # Contador de iteração
count_loop:
    beq $t0, $s3, end_count
    
    add $t1, $s2, $t0   # Endereço do status
    lb $t2, 0($t1)      # Carrega status
    
    beqz $t2, inc_vazio
    addi $s0, $s0, 1    # Incrementa não vazios
    j next_iter
inc_vazio:
    addi $s1, $s1, 1    # Incrementa vazios
next_iter:
    addi $t0, $t0, 1
    j count_loop

end_count:
    # Calcula porcentagem de não vazios
    mul $t0, $s0, 100   # não_vazios * 100
    div $s4, $t0, $s3   # s4 = (não_vazios * 100) / 40
    
    # Calcula porcentagem de vazios
    mul $t0, $s1, 100   # vazios * 100
    div $s5, $t0, $s3   # s5 = (vazios * 100) / 40

    # Imprime "Não vazios"
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
    li $a0, ')'         # Adiciona o parêntese fechando
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
    li $a0, ')'         # Adiciona o parêntese fechando
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
# SISTEMA DE ARMAZENAMENTO - PERSISTÊNCIA - I N A C A B A D O ####################################

# ======================================
# Função: cmd_salvar
# Descrição: Este comando salva tudo em "condominio.dat"
# Comando: salvar
# ======================================

cmd_salvar:
    addi $sp, $sp, -28
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # Descritor do arquivo
    sw $s1, 8($sp)      # Contador de bytes
    sw $s2, 12($sp)     # Temporário
    sw $s3, 16($sp)
    sw $s4, 20($sp)
    sw $s5, 24($sp)
    
    # Abrir arquivo com O_CREAT | O_WRONLY = 0x201 (513)
    li $v0, 13
    la $a0, filename
    li $a1, 0x201       # Corrigido para valor numérico direto
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
# Função: cmd_recarregar
# Descrição: Recarrega as informações salvas no arquivo externo na execução atual do programa. 
# Modificações não salvas serão perdidas e as informações salvas anteriormente recuperadas.  
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
# Função: cmd_formatar
# Descrição: Apaga todas as informações da execução atual do programa,
# deixando todos os apartamentos vazios. Este comando não deve salvar automaticamente no arquivo externo,
# sendo necessário usar posteriormente o comando “salvar” para registrar a formação no arquivo externo.
# Comando: formatar
# ======================================

# ======================================
# Função: cmd_formatar
# Versão pública do formatar com mensagem
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
# Função: clear_buffer
# Descrição: Preenche um buffer com zeros
# Entrada: $s0 = endereço do buffer
#          $s1 = tamanho do buffer
# ======================================
clear_buffer:
    addi $t0, $s1, 0   # Copiar contador
    move $t1, $s0      # Copiar endereço
clear_loop:
    beqz $t0, end_clear
    sb $zero, 0($t1)
    addi $t1, $t1, 1
    addi $t0, $t0, -1
    j clear_loop
end_clear:
    jr $ra


# ======================================
# Função: load_from_file (versão corrigida)
# Descrição: Carrega dados do arquivo com controle de mensagens
# Entrada: $a0 = flag (0: sem mensagem, 1: com mensagem)
# Se o arquivo não existir, cria um novo com dados zerados
# ======================================
load_from_file:
    addi $sp, $sp, -28
    sw $ra, 0($sp)
    sw $s0, 4($sp)      # Descritor do arquivo
    sw $s1, 8($sp)      # Bytes lidos/escritos
    sw $s2, 12($sp)     # Flag de mensagem
    sw $s3, 16($sp)     # Estado
    sw $s4, 20($sp)     # Temporário
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
    beqz $s2, skip_msg  # Se flag=0, não mostrar mensagem
    
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
# Função: cmd_formatar_internal
# Descrição: Formata dados sem imprimir mensagem
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
# Funções de String (da Lista de Exercício)
# ======================================

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
    # Entrada: $a0, $a1 - endereços das strings
    # Saída: $v0 - 0 (iguais), negativo (str1 < str2), positivo (str1 > str2)
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
    
    # Avança para o próximo caractere
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j strcmp_loop

strcmp_check:
    bnez $t3, strcmp_finish  # Se str1 terminou mas str2 não
    li $v0, 0                # Ambas terminaram, strings iguais
    jr $ra

strcmp_finish:
    # Calcula diferença entre os caracteres
    sub $v0, $t2, $t3
    jr $ra

strcmp_diff:
    sub $v0, $t2, $t3
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