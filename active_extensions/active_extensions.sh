#!/bin/bash

# Автор: Stanislav Rakitov
# Репозиторий: https://github.com/SkyrocketStan/CDR-Tools

# Параметры по умолчанию
CDR_DIR="$(pwd)"  # Директория с CDR-файлами
DAYS=30           # Глубина анализа в днях
DEBUG=false       # Режим отладки (по умолчанию выключен)

# Настраиваемые параметры поиска
SEARCH_PATTERN="^[1-9][0-9]{5}$"  # Регулярное выражение для поиска (по умолчанию: шестизначные номера, не начинающиеся с 0)
MIN_LENGTH=6                      # Минимальная длина номера
MAX_LENGTH=6                      # Максимальная длина номера
SEARCH_MODE="full"                # Режим поиска: "full" (по всей строке) или "position" (по позициям)
CALLING_POS=13                    # Начальная позиция для calling-num (по умолчанию 13, длина 10)
DIALED_POS=62                     # Начальная позиция для dialed-num (по умолчанию 62, длина 18)

# Функция вывода справки
show_help() {
    echo "Использование: $0 [ОПЦИИ] [ПУТЬ [ДНИ]] | [ДНИ]"
    echo "Скрипт для поиска номеров в CDR-файлах Avaya."
    echo
    echo "Без аргументов: ищет в текущей директории за $DAYS дней."
    echo "С аргументами:"
    echo "  60                   - ищет в текущей папке за 60 дней"
    echo "  /path/to/cdr         - ищет в указанной папке за $DAYS дней"
    echo "  /path/to/cdr 60      - ищет в указанной папке за 60 дней"
    echo
    echo "Опции:"
    echo "  --debug              - включает режим отладки"
    echo "  --cdr-dir DIR        - указывает директорию с CDR-файлами"
    echo "  --days DAYS          - задаёт глубину анализа в днях"
    echo "  --help               - показывает эту справку"
    echo
    echo "Примеры:"
    echo "  $0                   - поиск в текущей папке за $DAYS дней"
    echo "  $0 60                - поиск в текущей папке за 60 дней"
    echo "  $0 /var/log/cdr      - поиск в /var/log/cdr за $DAYS дней"
    echo "  $0 /var/log/cdr 60   - поиск в /var/log/cdr за 60 дней"
    echo "  $0 --debug --days 45 - поиск в текущей папке за 45 дней с отладкой"
    exit 0
}

# Обработка аргументов
if [[ $# -eq 0 ]]; then
    # Без параметров: используем текущую папку и дефолтные дни
    :
elif [[ "$1" == "--help" ]]; then
    show_help
elif [[ $# -eq 1 && "$1" =~ ^[0-9]+$ ]]; then
    # Один аргумент — число дней
    DAYS="$1"
elif [[ $# -eq 1 && -d "$1" ]]; then
    # Один аргумент — путь
    CDR_DIR="$1"
elif [[ $# -eq 2 && -d "$1" && "$2" =~ ^[0-9]+$ ]]; then
    # Два аргумента — путь и дни
    CDR_DIR="$1"
    DAYS="$2"
else
    # Обработка именованных параметров или ошибка
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug)
                DEBUG=true
                shift
                ;;
            --cdr-dir)
                if [[ -d "$2" ]]; then
                    CDR_DIR="$2"
                    shift 2
                else
                    echo "Ошибка: директория '$2' не существует."
                    exit 1
                fi
                ;;
            --days)
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    DAYS="$2"
                    shift 2
                else
                    echo "Ошибка: '$2' не является числом."
                    exit 1
                fi
                ;;
            --help)
                show_help
                ;;
            *)
                echo "Неизвестный параметр: $1"
                echo
                show_help
                exit 1
                ;;
        esac
    done
fi

# Определяем имена файлов на основе имени скрипта
SCRIPT_NAME="$(basename "$0" .sh)"
LOG_FILE="./${SCRIPT_NAME}.log"
OUTPUT_FILE="./${SCRIPT_NAME}.txt"

# Логирование
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - [$1] $2" | tee -a "$LOG_FILE"
}

# Проверяем директорию
if [[ ! -d "$CDR_DIR" ]]; then
    log "ERROR" "Директория $CDR_DIR не найдена."
    exit 1
fi

# Очистка старых данных
> "$LOG_FILE"
> "$OUTPUT_FILE"

# Флаг наличия файлов
FILES_FOUND=false

# Обход файлов
for ((i=1; i<=DAYS; i++)); do
    FILE_DATE=$(date --date="$i days ago" +%Y-%m-%d)
    FILES=("$CDR_DIR"/cdr_${FILE_DATE}_*.log)
    
    if [[ ! -e "${FILES[0]}" ]]; then
        log "INFO" "Нет файлов за $FILE_DATE."
        continue
    fi
    
    FILES_FOUND=true
    
    for FILE in "${FILES[@]}"; do
        [[ ! -s "$FILE" ]] && log "WARNING" "Файл $FILE пуст." && continue
        [[ ! -r "$FILE" ]] && log "ERROR" "Нет доступа к файлу $FILE." && continue
        
        log "INFO" "Обрабатываю $FILE..."
        
        # Обработка файла: поиск номеров с настраиваемыми параметрами
        awk -v debug="$DEBUG" -v log_file="$LOG_FILE" -v pattern="$SEARCH_PATTERN" \
            -v min_len="$MIN_LENGTH" -v max_len="$MAX_LENGTH" -v mode="$SEARCH_MODE" \
            -v calling_pos="$CALLING_POS" -v dialed_pos="$DIALED_POS" \
            '{
                if (mode == "full") {
                    # Поиск по всей строке
                    gsub(/[ \t]+/, " ", $0)
                    split($0, fields, " ")
                    for (i in fields) {
                        num = fields[i]
                        gsub(/[^0-9]/, "", num)
                        if (length(num) >= min_len && length(num) <= max_len && num ~ pattern) {
                            if (debug == "true") {
                                print strftime("%Y-%m-%d %H:%M:%S") " - [DEBUG] Найден номер: " num " в строке: " $0 >> log_file
                            }
                            print num
                        }
                    }
                } else if (mode == "position") {
                    # Поиск по заданным позициям
                    calling_num = substr($0, calling_pos, 10)
                    dialed_num = substr($0, dialed_pos, 18)
                    gsub(/[^0-9]/, "", calling_num)
                    gsub(/[^0-9]/, "", dialed_num)
                    
                    if (length(calling_num) >= min_len && length(calling_num) <= max_len && calling_num ~ pattern) {
                        if (debug == "true") {
                            print strftime("%Y-%m-%d %H:%M:%S") " - [DEBUG] Найден номер: " calling_num " (calling-num) в строке: " $0 >> log_file
                        }
                        print calling_num
                    }
                    if (length(dialed_num) >= min_len && length(dialed_num) <= max_len && dialed_num ~ pattern) {
                        if (debug == "true") {
                            print strftime("%Y-%m-%d %H:%M:%S") " - [DEBUG] Найден номер: " dialed_num " (dialed-num) в строке: " $0 >> log_file
                        }
                        print dialed_num
                    }
                }
            }' "$FILE" >> "$OUTPUT_FILE"
    done
done

# Выводим сообщение, если файлы не были найдены
if [[ "$FILES_FOUND" = false ]]; then
    log "INFO" "Не найдено ни одного файла за указанный период."
fi

# Убираем дубликаты, сортируем
LC_ALL=C sort -u -o "$OUTPUT_FILE" "$OUTPUT_FILE"

# Итоговый отчёт
if [[ -s "$OUTPUT_FILE" ]]; then
    log "INFO" "Готово! Найдено $(wc -l < "$OUTPUT_FILE") уникальных номеров."
else
    log "INFO" "Номера не найдены. Удаляю пустой файл."
    rm -f "$OUTPUT_FILE"
fi#!/bin/bash

# Параметры скрипта
CDR_DIR="${1:-$(pwd)}"  # Папка с CDR-файлами (по умолчанию текущая директория)
DAYS="${2:-30}"         # Количество дней для анализа (по умолчанию 30)

# Файл лога
LOG_FILE="./active_extensions.log"
OUTPUT_FILE="./active_extensions.txt"

# Формат логирования
LOG_FORMAT="%Y-%m-%d %H:%M:%S"
log() {
    echo "$(date +"$LOG_FORMAT") - [$1] $2" | tee -a "$LOG_FILE"
}

# Проверяем доступность директории CDR_DIR
if [[ ! -d "$CDR_DIR" ]]; then
    log "ERROR" "Директория $CDR_DIR не существует или недоступна."
    exit 1
fi

# Динамическое количество потоков
CORES=$(( $(nproc) / 2 ))
[[ $CORES -lt 1 ]] && CORES=1
[[ $CORES -gt 4 ]] && CORES=4

# Функция для обработки одного файла
process_file() {
    local FILE="$1"
    log "INFO" "Обрабатываю $FILE..."
    if [[ ! -s "$FILE" ]]; then
        log "WARNING" "Файл $FILE пуст."
        return
    fi
    if [[ ! -r "$FILE" ]]; then
