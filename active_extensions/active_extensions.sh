#!/bin/bash

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
        log "ERROR" "Нет доступа к файлу $FILE."
        return
    fi
    awk -v date="$(date +"%Y-%m-%d %H:%M:%S")" '{ if ($13 ~ /^[0-9]{6}$/) print date, $13; if ($21 ~ /^[0-9]{6}$/) print date, $21; }' "$FILE" >> "$OUTPUT_FILE"
}

# Экспортируем функции для параллельного выполнения
export -f log process_file
export OUTPUT_FILE LOG_FILE LOG_FORMAT

# Перебираем файлы за последние $DAYS дней, включая сегодняшний день
TOTAL_FILES=0
PROCESSED_FILES=0

for ((i=0; i<=DAYS; i++)); do
    FILE_DATE=$(date --date="$i days ago" +%Y-%m-%d)
    mapfile -t FILES < <(find "$CDR_DIR" -maxdepth 1 -name "cdr_${FILE_DATE}_*.log" -print)
    
    if [[ ${#FILES[@]} -eq 0 ]]; then
        log "INFO" "Файлы за $FILE_DATE не найдены."
        continue
    fi

    TOTAL_FILES=$((TOTAL_FILES + ${#FILES[@]}))

    for FILE in "${FILES[@]}"; do
        process_file "$FILE" &
        (( $(jobs | wc -l) >= CORES )) && wait
    done

    PROCESSED_FILES=$((PROCESSED_FILES + ${#FILES[@]}))

done

wait  # Ждём завершения всех фоновых процессов

# Если не обработано ни одного файла, не создаем пустые файлы
if [[ $PROCESSED_FILES -gt 0 ]]; then
    # Убираем дубликаты
    sort -u -o "$OUTPUT_FILE" "$OUTPUT_FILE"

    # Итоговый отчёт
    UNIQUE_NUMBERS=$(wc -l < "$OUTPUT_FILE")
    
    log "INFO" "Готово! Обработано $PROCESSED_FILES из $TOTAL_FILES файлов."
    log "INFO" "Найдено $UNIQUE_NUMBERS уникальных шестизначных номеров."
    
    if [[ $UNIQUE_NUMBERS -gt 0 ]]; then
        log "INFO" "Список активных шестизначных номеров за $DAYS дней сохранен в $OUTPUT_FILE."
    else
        log "INFO" "Найдено 0 уникальных номеров. Файл $OUTPUT_FILE не создан."
        rm -f "$OUTPUT_FILE"
    fi
else
    log "INFO" "Обработано 0 файлов. Ничего не найдено, файлы логов не созданы."
    rm -f "$LOG_FILE"
fi
