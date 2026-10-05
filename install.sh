#!/usr/bin/env bash
# =============================================================================
#  install.sh — автоустановка форка Sergeydigl3/zapret-discord-youtube-linux
#  По мотивам гайда: https://github.com/h1nchek/zapret-installer
#
#  Использование:
#     ./install.sh [опции]
#
#  Опции:
#     --dir PATH         куда ставить (по умолчанию ~/zapret-discord-youtube-linux)
#     --strategy NAME    выставить стратегию, например general.bat
#     --domains LIST     домены через запятую для list-general.txt
#     --tune             после установки прогнать auto_tune_youtube.sh
#     --desktop          поставить ярлык в меню приложений
#     --nopasswd         выполнить ./service.sh setup-permissions (NOPASSWD для nft/nfqws)
#     --no-service       не запускать меню установки сервиса
#     --uninstall        остановить сервис и удалить установку
#     -y, --yes          не задавать вопросов
#     -h, --help         эта справка
# =============================================================================
set -Eeuo pipefail

REPO_URL="https://github.com/Sergeydigl3/zapret-discord-youtube-linux.git"
SERVICE_NAME="zapret_discord_youtube"   # именно с подчёркиваниями, не с дефисами!
INSTALL_DIR="${HOME}/zapret-discord-youtube-linux"
STRATEGY=""
DOMAINS=""
DO_TUNE=0
DO_DESKTOP=0
DO_NOPASSWD=0
DO_SERVICE=1
DO_UNINSTALL=0
ASSUME_YES=0

# ---------- вывод ------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
  C_BLU=$'\033[34m'; C_BLD=$'\033[1m'; C_OFF=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_BLD=""; C_OFF=""
fi
STEP=0
step() { STEP=$((STEP + 1)); printf '\n%s[%d] %s%s\n' "${C_BLU}${C_BLD}" "$STEP" "$*" "$C_OFF"; }
ok()   { printf '%s  ✔ %s%s\n' "$C_GRN" "$*" "$C_OFF"; }
warn() { printf '%s  ⚠ %s%s\n' "$C_YEL" "$*" "$C_OFF" >&2; }
info() { printf '    %s\n' "$*"; }
die()  { printf '%s  ✘ %s%s\n' "$C_RED" "$*" "$C_OFF" >&2; exit 1; }

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

confirm() {
  [[ $ASSUME_YES -eq 1 ]] && return 0
  local ans
  read -r -p "    $1 [y/N] " ans || true
  [[ "$ans" =~ ^[YyДд]$ ]]
}

# ---------- откат при ошибке -------------------------------------------------
CLONED_NOW=0
CONF_BACKUP=""
ROLLBACK_ARMED=0

rollback() {
  local code=$?
  trap - ERR
  [[ $ROLLBACK_ARMED -eq 1 ]] || exit "$code"
  printf '\n%s  ✘ Что-то пошло не так (код %s, строка %s). Откатываю изменения...%s\n' \
    "$C_RED" "$code" "${1:-?}" "$C_OFF" >&2
  if [[ -n "$CONF_BACKUP" && -f "$CONF_BACKUP" ]]; then
    cp -f "$CONF_BACKUP" "${INSTALL_DIR}/conf.env" && warn "conf.env восстановлен из бэкапа"
  fi
  if [[ $CLONED_NOW -eq 1 && -d "$INSTALL_DIR" ]]; then
    rm -rf -- "$INSTALL_DIR" && warn "Удалён свежесклонированный каталог $INSTALL_DIR"
  fi
  warn "Установленные пакеты (git, nftables и т.д.) не удаляются — они могут быть нужны системе."
  exit "$code"
}
trap 'rollback $LINENO' ERR

# ---------- аргументы --------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)        [[ $# -ge 2 ]] || die "--dir требует путь"; INSTALL_DIR="$2"; shift 2 ;;
    --strategy)   [[ $# -ge 2 ]] || die "--strategy требует имя"; STRATEGY="$2"; shift 2 ;;
    --domains)    [[ $# -ge 2 ]] || die "--domains требует список"; DOMAINS="$2"; shift 2 ;;
    --tune)       DO_TUNE=1; shift ;;
    --desktop)    DO_DESKTOP=1; shift ;;
    --nopasswd)   DO_NOPASSWD=1; shift ;;
    --no-service) DO_SERVICE=0; shift ;;
    --uninstall)  DO_UNINSTALL=1; shift ;;
    -y|--yes)     ASSUME_YES=1; shift ;;
    -h|--help)    usage ;;
    *)            die "Неизвестная опция: $1 (см. --help)" ;;
  esac
done

# ---------- проверки окружения ----------------------------------------------
[[ ${EUID} -ne 0 ]] || die "Не запускай от root. Скрипт сам вызовет sudo там, где нужно."
command -v sudo >/dev/null || die "Нужен sudo."

PKG=""
detect_distro() {
  local id="" like=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    id="$(. /etc/os-release && echo "${ID:-}")"
    like="$(. /etc/os-release && echo "${ID_LIKE:-}")"
  fi
  case " $id $like " in
    *" arch "*)              PKG="pacman" ;;
    *" debian "*|*" ubuntu "*) PKG="apt" ;;
    *)                       PKG="" ;;
  esac
}

# ---------- удаление ---------------------------------------------------------
uninstall() {
  step "Удаление"
  if command -v systemctl >/dev/null && systemctl list-unit-files 2>/dev/null | grep -q "^${SERVICE_NAME}"; then
    sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    ok "Сервис $SERVICE_NAME остановлен и отключён"
    local unit="/etc/systemd/system/${SERVICE_NAME}.service"
    if [[ -f "$unit" ]]; then
      sudo rm -f -- "$unit"
      sudo systemctl daemon-reload
      ok "Удалён $unit"
    fi
  else
    warn "Сервис systemd с именем $SERVICE_NAME не найден."
    info "Если у тебя другая init-система (OpenRC/runit/dinit/s6), сними сервис через меню: ./service.sh"
  fi

  if [[ -d "$INSTALL_DIR" ]]; then
    if confirm "Удалить каталог $INSTALL_DIR (вместе с conf.env и list-general.txt)?"; then
      rm -rf -- "$INSTALL_DIR"
      ok "Каталог удалён"
    else
      info "Каталог оставлен."
    fi
  else
    warn "Каталог $INSTALL_DIR не найден."
  fi

  info "Если ты запускал setup-permissions, проверь /etc/sudoers.d/ и убери ненужные NOPASSWD-правила."
  info "Таблицы nftables после остановки сервиса можно проверить так: sudo nft list tables"
  ok "Готово."
  exit 0
}
[[ $DO_UNINSTALL -eq 1 ]] && uninstall

# ---------- 1. система -------------------------------------------------------
step "Проверка системы"
detect_distro
case "$PKG" in
  pacman) ok "Arch-подобная система, будет использован pacman" ;;
  apt)    ok "Debian/Ubuntu-подобная система, будет использован apt" ;;
  *)      warn "Дистрибутив не распознан. Зависимости (git, nftables, сборочные инструменты) поставь вручную."
          confirm "Продолжить без установки пакетов?" || die "Прервано." ;;
esac

if command -v nft >/dev/null; then
  tables="$(sudo nft list tables 2>/dev/null || true)"
  if [[ -n "$tables" ]]; then
    warn "В nftables уже есть таблицы — возможен конфликт с твоими правилами:"
    printf '%s\n' "$tables" | sed 's/^/        /'
    info "Скрипт работает только с nftables. Если там чужой файрвол, убедись, что правила не пересекутся."
  else
    ok "nftables чистый"
  fi
fi

if command -v iptables >/dev/null && iptables --version 2>/dev/null | grep -qi legacy; then
  warn "Обнаружен iptables-legacy. Возможен конфликт с nftables — см. раздел «Зависимости» в гайде."
fi

# с этого момента изменения можно откатывать
ROLLBACK_ARMED=1

# ---------- 2. зависимости ---------------------------------------------------
step "Установка зависимостей"
case "$PKG" in
  pacman) sudo pacman -Syu --needed --noconfirm base-devel nftables git ;;
  apt)    sudo apt-get update && sudo apt-get install -y build-essential nftables git ;;
  *)      command -v git >/dev/null || die "git не найден." ;;
esac
ok "Зависимости на месте"

# ---------- 3. репозиторий ---------------------------------------------------
step "Получение репозитория → $INSTALL_DIR"
if [[ -d "$INSTALL_DIR/.git" ]]; then
  info "Каталог уже есть, обновляю (git pull)"
  git -C "$INSTALL_DIR" pull --ff-only
elif [[ -e "$INSTALL_DIR" ]]; then
  die "$INSTALL_DIR существует, но это не git-репозиторий. Укажи другой путь через --dir."
else
  git clone "$REPO_URL" "$INSTALL_DIR"
  CLONED_NOW=1
fi
cd "$INSTALL_DIR"
[[ -f service.sh ]] || die "В репозитории нет service.sh — структура форка изменилась?"
chmod +x service.sh
[[ -f auto_tune_youtube.sh ]] && chmod +x auto_tune_youtube.sh
ok "Репозиторий готов"

# ---------- 4. зависимости форка --------------------------------------------
step "Загрузка nfqws и стратегий (download-deps --default)"
./service.sh download-deps --default
ok "nfqws и стратегии скачаны"

# ---------- 5. конфиг --------------------------------------------------------
step "Настройка conf.env"
if [[ -f conf.env ]]; then
  CONF_BACKUP="$(mktemp)"
  cp -f conf.env "$CONF_BACKUP"
  cp -f conf.env conf.env.bak
  info "Бэкап: ${INSTALL_DIR}/conf.env.bak"
  if grep -q '^MODE_FILTER=' conf.env; then
    sed -i 's/^MODE_FILTER=.*/MODE_FILTER=hostlist/' conf.env
  else
    printf '\nMODE_FILTER=hostlist\n' >> conf.env
  fi
  ok "MODE_FILTER=hostlist (фильтрация по списку доменов, а не всего трафика)"
else
  warn "conf.env не найден — пропускаю. Проверь режим фильтрации вручную после первого запуска."
fi

if [[ -n "$STRATEGY" ]]; then
  ./service.sh config set "$STRATEGY"
  ok "Стратегия: $STRATEGY"
fi

if [[ -n "$DOMAINS" ]]; then
  touch list-general.txt
  IFS=',' read -r -a dom_arr <<< "$DOMAINS"
  for d in "${dom_arr[@]}"; do
    d="${d//[[:space:]]/}"
    [[ -z "$d" ]] && continue
    if ! grep -qxF "$d" list-general.txt; then
      printf '%s\n' "$d" >> list-general.txt
      ok "Добавлен домен: $d"
    fi
  done
else
  info "Не забудь вписать нужные домены в ${INSTALL_DIR}/list-general.txt (только то, чем пользуешься)."
fi

# ---------- 6. необязательное -----------------------------------------------
if [[ $DO_NOPASSWD -eq 1 ]]; then
  step "Права без пароля (setup-permissions)"
  warn "Это добавит NOPASSWD для nft и nfqws — любой процесс от твоего пользователя сможет менять правила файрвола без пароля."
  if confirm "Продолжить?"; then
    ./service.sh setup-permissions
    ok "Права настроены"
  else
    info "Пропущено."
  fi
fi

if [[ $DO_TUNE -eq 1 ]]; then
  step "Автоподбор стратегии (auto_tune_youtube.sh)"
  if [[ -x auto_tune_youtube.sh ]]; then
    info "Это займёт несколько минут."
    sudo ./auto_tune_youtube.sh
    ok "Автоподбор завершён"
  else
    warn "auto_tune_youtube.sh не найден — пропускаю."
  fi
fi

if [[ $DO_DESKTOP -eq 1 ]]; then
  step "Ярлык в меню приложений"
  ./service.sh desktop install
  ok "Ярлык установлен"
fi

# установка сервиса идёт через интерактивное меню (как в гайде)
ROLLBACK_ARMED=0   # установка завершена, дальше откатывать нечего
if [[ $DO_SERVICE -eq 1 ]]; then
  step "Автозапуск"
  info "Сейчас откроется меню service.sh."
  info "Выбери: «Управление сервисом» → «Установить». Скрипт сам определит init-систему."
  if [[ $ASSUME_YES -eq 1 ]]; then
    warn "Режим --yes: меню не открываю. Запусти потом вручную: cd $INSTALL_DIR && ./service.sh"
  else
    read -r -p "    Нажми Enter, чтобы открыть меню..." _ || true
    ./service.sh || warn "Меню завершилось с ошибкой — запусти ./service.sh вручную."
  fi
fi

# ---------- итог -------------------------------------------------------------
printf '\n%s%s=== Готово ===%s\n' "$C_GRN" "$C_BLD" "$C_OFF"
cat <<EOF
  Каталог:   $INSTALL_DIR
  Конфиг:    $INSTALL_DIR/conf.env
  Домены:    $INSTALL_DIR/list-general.txt

  Полезные команды (имя сервиса — с подчёркиваниями!):
    sudo systemctl status  $SERVICE_NAME
    sudo systemctl restart $SERVICE_NAME
    systemctl list-units | grep zapret

  Если YouTube не открывается:
    1) отключи QUIC в браузере: chrome://flags/#enable-quic → Disabled
    2) попробуй отключить Kyber: chrome://flags/#use-kyber
    3) запусти автоподбор:      sudo $INSTALL_DIR/auto_tune_youtube.sh

  Обновление:   cd $INSTALL_DIR && git pull && ./service.sh download-deps --default \\
                && sudo systemctl restart $SERVICE_NAME
  Удаление:     $0 --uninstall
EOF
