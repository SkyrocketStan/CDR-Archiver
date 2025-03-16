#!/bin/bash

# Автор: Stanislav Rakitov
# Репозиторий: https://github.com/SkyrocketStan/CDR-Tools

# Универсальные переменные
SCRIPT_NAME=$(basename "$0" .sh)
LOG_DIR="."
LOG_FILE="$LOG_DIR/$SCRIPT_NAME.log"
SOURCE_DIR=""
DEST_DIR=""
FILE_PATTERN="*.csv"
MAX_LOG_SIZE=10485760  # 10MB
MAX_LOG_FILES=5

# Функция логирования
log() {
    local level="$1"
    shift
    if [[ ! -w "$LOG_FILE" ]]; then
        LOG_FILE="$LOG_DIR/$SCRIPT_NAME-$(date +'%Y%m%d%H%M%S').log"
        touch "$LOG_FILE"
        chmod 666 "$LOG_FILE"
    fi
    echo "$(date +'%Y-%m-%d %H:%M:%S') [$level] \"$*\"" | tee -a "$LOG_FILE" || echo "Ошибка записи в лог"
}

# Ротация логов
rotate_logs() {
    if [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE") -ge "$MAX_LOG_SIZE" ]]; then
        for ((i=MAX_LOG_FILES-1; i>0; i--)); do
            [[ -f "$LOG_FILE.$i.gz" ]] && mv "$LOG_FILE.$i.gz" "$LOG_FILE.$((i+1)).gz"
        done
        mv "$LOG_FILE" "$LOG_FILE.1"
        gzip -f "$LOG_FILE.1"
    fi
}

# Вывод справки
usage() {
    echo "Использование: $SCRIPT_NAME --sourcedir <директория> --destdir <директория> [--logdir <директория>] [--pattern <маска>]"
    echo "ИЛИ"
    echo "$SCRIPT_NAME <исходная_директория> <целевой_каталог> [лог_каталог]"
    exit 1
}

# Обработчик прерывания
trap 'log "ERROR" "Скрипт прерван пользователем"; exit 1' SIGINT SIGTERM SIGQUIT

# Обработка аргументов
if [[ "$#" -eq 0 ]]; then
    usage
fi

POSITIONAL_ARGS=()
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --sourcedir)
            SOURCE_DIR="$2"
            shift 2
            ;;
        --destdir)
            DEST_DIR="$2"
            shift 2
            ;;
        --logdir)
            LOG_DIR="$2"
            LOG_FILE="$LOG_DIR/$SCRIPT_NAME.log"
            shift 2
            ;;
        --pattern)
            FILE_PATTERN="$2"
            shift 2
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Поддержка позиционных аргументов
if [[ "${#POSITIONAL_ARGS[@]}" -ge 2 ]]; then
    SOURCE_DIR="${POSITIONAL_ARGS[0]}"
    DEST_DIR="${POSITIONAL_ARGS[1]}"
    [[ "${#POSITIONAL_ARGS[@]}" -ge 3 ]] && LOG_DIR="${POSITIONAL_ARGS[2]}" && LOG_FILE="$LOG_DIR/$SCRIPT_NAME.log"
fi

rotate_logs

# Проверка существования директорий
mkdir -p "$DEST_DIR"

if [[ ! -d "$SOURCE_DIR" ]]; then
    log "ERROR" "Директория $SOURCE_DIR не найдена."
    exit 1
fi

# Проверка прав доступа
if [[ ! -r "$SOURCE_DIR" || ! -x "$SOURCE_DIR" ]]; then
    log "ERROR" "Недостаточно прав для работы с $SOURCE_DIR."
    exit 1
fi

# Поиск файлов для обработки
COUNT_TOTAL=0
COUNT_MOVED=0

set -o pipefail

files=$(find "$SOURCE_DIR" -maxdepth 1 -type f -name "$FILE_PATTERN" -print0 2>/dev/null || true)
if [[ -z "$files" ]]; then
    log "WARNING" "Нет файлов для обработки."
    exit 0
fi

while IFS= read -r -d '' file; do
    ((COUNT_TOTAL++))
    BASENAME=$(basename "$file")
    
    if [[ ! -w "$file" ]]; then
        log "ERROR" "Нет прав на изменение $BASENAME. Файл пропущен."
        continue
    fi

    chmod 666 "$file" || {
        log "ERROR" "Не удалось установить права 666 на $BASENAME. Файл не перемещён."
        continue
    }

    SIZE=$(stat -c%s "$file")
    if mv "$file" "$DEST_DIR/$BASENAME"; then
        ((COUNT_MOVED++))
        log "INFO" "Файл перемещен: $BASENAME (${SIZE}B)"
    else
        log "ERROR" "Ошибка перемещения: $BASENAME"
    fi

done < <(find "$SOURCE_DIR" -maxdepth 1 -type f -name "$FILE_PATTERN" -print0 2>/dev/null || true)

if [[ "$COUNT_TOTAL" -eq 0 ]]; then
    log "WARNING" "Нет файлов для обработки."
    exit 0
fi

log "INFO" "Обработано $COUNT_MOVED из $COUNT_TOTAL файлов."
exit 0
