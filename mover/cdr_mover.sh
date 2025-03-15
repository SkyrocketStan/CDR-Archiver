#!/bin/bash

### Настраиваемые параметры ###

# Исходная директория с CDR-файлами
SOURCE_DIR="/path/to/source"

# Целевая директория
DEST_DIR="/path/to/destination"

# Лог-файл
LOG_DIR="/path/to/logs"
LOG_FILE="${LOG_DIR}/cdr_mover.log"

# Максимальный размер лог-файла (в байтах)
MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10 МБ

### Логика скрипта ###

# Функция для логирования
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

# Проверка доступности директорий
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Ошибка: исходная директория $SOURCE_DIR не существует или недоступна." >&2
    exit 1
fi

if [[ ! -d "$DEST_DIR" ]]; then
    echo "Ошибка: целевая директория $DEST_DIR не существует или недоступна." >&2
    exit 1
fi

if [[ ! -d "$LOG_DIR" ]]; then
    echo "Ошибка: директория для логов $LOG_DIR не существует или недоступна." >&2
    exit 1
fi

# Проверка размера лог-файла и ротация
if [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]]; then
    mv "$LOG_FILE" "${LOG_FILE}.1" 2>/dev/null
fi

# Логирование начала выполнения
log "Начало перемещения CDR-файлов из ${SOURCE_DIR} в ${DEST_DIR}"

# Подсчет общего количества файлов
TOTAL_FILES=$(find "$SOURCE_DIR" -type f -name "*.cdr" | wc -l)
SUCCESS_COUNT=0

# Перемещение файлов
find "$SOURCE_DIR" -type f -name "*.cdr" | while read -r file; do
    # Перемещаем файл
    if mv "$file" "$DEST_DIR"; then
        log "Файл $file успешно перемещен."
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        chmod 666 "${DEST_DIR}/$(basename "$file")"  # Меняем права доступа
    else
        log "Ошибка при перемещении файла $file."
    fi
done

# Логирование завершения выполнения
log "Перемещение CDR-файлов завершено. Успешно обработано: ${SUCCESS_COUNT}/${TOTAL_FILES} файлов."

# Вывод сообщения об успешном выполнении
echo "Скрипт успешно выполнен. Успешно обработано: ${SUCCESS_COUNT}/${TOTAL_FILES} файлов. Подробности в логе: $LOG_FILE"
