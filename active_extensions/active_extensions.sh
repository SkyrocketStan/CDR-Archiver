#!/bin/bash

# Active Extensions Extractor
# GitHub: https://github.com/SkyrocketStan/CDR-Tools
# Copyright (C) 2025 Stanislav Rakitov
# Licensed under the MIT License

# Параметры по умолчанию
CDR_DIR="$(pwd)"          # Директория с CDR-файлами
DAYS=30                   # Глубина анализа в днях
DEBUG=false               # Режим отладки (по умолчанию выключен)

# Настраиваемые параметры поиска
SEARCH_PATTERN="^[1-9][0-9]{5}$"  # Регулярное выражение для поиска (по умолчанию: шестизначные номера, не начинающиеся с 0)
MIN_LENGTH=6                      # Минимальная длина номера
MAX_LENGTH=6                      # Максимальная длина номера
SEARCH_MODE="full"                # Режим поиска: "full" или "position"
CALLING_POS=13                    # Начальная позиция для calling-num
CALLING_LEN=10                    # Длина поля calling-num
DIALED_POS=62                     # Начальная позиция для dialed-num
DIALED_LEN=18                     # Длина поля dialed-num

# Настраиваемые параметры файлов
LOG_PATTERN="cdr_%Y-%m-%d_*.log"  # Шаблон имени CDR-файлов
OUTPUT_FILE_NAME=""               # Имя выходного файла (пусто = по имени скрипта)
LOG_FILE_NAME=""                  # Имя лог-файла (пусто = по имени скрипта)

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

# Логирование
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - [$1] $2" | tee -a "$LOG_FILE" 2>/dev/null || {
        echo "Ошибка: невозможно записать в лог-файл $LOG_FILE" >&2
        exit 1
    }
}

# Обработка аргументов
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
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                DAYS="$1"
            elif [[ -d "$1" ]]; then
                CDR_DIR="$1"
            else
                echo "Неизвестный параметр или некорректный аргумент: $1"
                echo
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Установка имён файлов на основе имени скрипта, если не переопределено
SCRIPT_NAME="$(basename "$0" .sh)"
[[ -z "$OUTPUT_FILE_NAME" ]] && OUTPUT_FILE="./${SCRIPT_NAME}.txt" || OUTPUT_FILE="$OUTPUT_FILE_NAME"
[[ -z "$LOG_FILE_NAME" ]] && LOG_FILE="./${SCRIPT_NAME}.log" || LOG_FILE="$LOG_FILE_NAME"

# Проверки перед началом
[[ ! -d "$CDR_DIR" ]] && { echo "Ошибка: директория '$CDR_DIR' не существует."; exit 1; }
[[ $DAYS -lt 0 ]] && { echo "Ошибка: DAYS не может быть отрицательным."; exit 1; }
[[ $DAYS -gt 1000 ]] && { echo "Предупреждение: DAYS ($DAYS) слишком большое, может занять много времени."; }
[[ "$LOG_PATTERN" != *%Y-%m-%d* ]] && { echo "Предупреждение: LOG_PATTERN не содержит %Y-%m-%d, даты не будут заменены."; }
[[ $CALLING_LEN -le 0 || $DIALED_LEN -le 0 ]] && { echo "Ошибка: CALLING_LEN и DIALED_LEN должны быть положительными."; exit 1; }

# Очистка старых данных
> "$LOG_FILE" 2>/dev/null || { echo "Ошибка: нет доступа к $LOG_FILE"; exit 1; }
> "$OUTPUT_FILE" 2>/dev/null || { echo "Ошибка: нет доступа к $OUTPUT_FILE"; exit 1; }

# Флаг наличия файлов
FILES_FOUND=false

# Обход файлов
for ((i=0; i<DAYS; i++)); do
    FILE_DATE=$(date --date="$i days ago" +%Y-%m-%d)
    PATTERN=$(echo "$LOG_PATTERN" | sed "s/%Y-%m-%d/$FILE_DATE/g")
    FILES=("$CDR_DIR"/$PATTERN)
    
    if [[ ! -e "${FILES[0]}" ]]; then
        log "INFO" "Нет файлов за $FILE_DATE (шаблон: $PATTERN)."
        continue
    fi
    
    FILES_FOUND=true
    
    for FILE in "${FILES[@]}"; do
        [[ ! -s "$FILE" ]] && log "WARNING" "Файл $FILE пуст." && continue
        [[ ! -r "$FILE" ]] && log "ERROR" "Нет доступа к файлу $FILE." && continue
        
        log "INFO" "Обрабатываю $FILE..."
        
        # Обработка файла: поиск номеров
        awk -v debug="$DEBUG" -v log_file="$LOG_FILE" -v pattern="$SEARCH_PATTERN" \
            -v min_len="$MIN_LENGTH" -v max_len="$MAX_LENGTH" -v mode="$SEARCH_MODE" \
            -v calling_pos="$CALLING_POS" -v calling_len="$CALLING_LEN" \
            -v dialed_pos="$DIALED_POS" -v dialed_len="$DIALED_LEN" \
            '
            function process_num(num, context) {
                gsub(/[^0-9]/, "", num)
                if (length(num) >= min_len && length(num) <= max_len && num ~ pattern) {
                    if (debug == "true") {
                        print strftime("%Y-%m-%d %H:%M:%S") " - [DEBUG] Найден номер: " num " (" context ") в строке: " $0 >> log_file
                    }
                    print num
                }
            }
            {
                if (mode == "full") {
                    gsub(/[ \t]+/, " ", $0)
                    split($0, fields, " ")
                    for (i in fields) {
                        process_num(fields[i], "full")
                    }
                } else if (mode == "position") {
                    if (length($0) < calling_pos + calling_len || length($0) < dialed_pos + dialed_len) {
                        if (debug == "true") {
                            print strftime("%Y-%m-%d %H:%M:%S") " - [DEBUG] Строка слишком короткая: " $0 >> log_file
                        }
                    } else {
                        process_num(substr($0, calling_pos, calling_len), "calling-num")
                        process_num(substr($0, dialed_pos, dialed_len), "dialed-num")
                    }
                } else {
                    print "Ошибка: неизвестный SEARCH_MODE: " mode > "/dev/stderr"
                    exit 1
                }
            }' "$FILE" >> "$OUTPUT_FILE" 2>>"$LOG_FILE"
    done
done

# Выводим сообщение, если файлы не были найдены
[[ "$FILES_FOUND" = false ]] && log "INFO" "Не найдено ни одного файла за указанный период."

# Убираем дубликаты, сортируем
LC_ALL=C sort -u -o "$OUTPUT_FILE" "$OUTPUT_FILE" 2>>"$LOG_FILE" || {
    log "ERROR" "Не удалось отсортировать $OUTPUT_FILE"
    exit 1
}

# Итоговый отчёт
if [[ -s "$OUTPUT_FILE" ]]; then
    log "INFO" "Готово! Найдено $(wc -l < "$OUTPUT_FILE") уникальных номеров."
else
    log "INFO" "Номера не найдены. Удаляю пустой файл."
    rm -f "$OUTPUT_FILE" 2>/dev/null
fi
