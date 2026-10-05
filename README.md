<div align="center">

# ⚡ zapret-installer

**Автоустановщик zapret для Linux и Windows.**

![Linux](https://img.shields.io/badge/Linux-Arch%20%7C%20Debian%20%7C%20Ubuntu-1793D1?style=for-the-badge&logo=linux&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=for-the-badge&logo=windows&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)

</div>

---

## Что это

Обёртки, которые ставят и настраивают готовые сборки [zapret](https://github.com/bol-van/zapret):

| Система | Что ставится | Скрипт |
|---|---|---|
| 🐧 Linux | [Sergeydigl3/zapret-discord-youtube-linux](https://github.com/Sergeydigl3/zapret-discord-youtube-linux) | `install.sh` |
| 🪟 Windows | [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) | `install-windows.bat` |

Сам zapret я не писал. Это только удобная установка поверх чужой работы, подробности в разделе «Благодарности».

---

## 🐧 Linux

```bash
curl -fsSLO https://raw.githubusercontent.com/h1nchek/zapret-installer/main/install.sh
less install.sh        # посмотри, что запускаешь, это нормальная привычка
bash install.sh --domains youtube.com,discord.com
```

Что делает скрипт:
- ставит зависимости (`pacman` или `apt`);
- клонирует форк и скачивает `nfqws` со стратегиями;
- переключает фильтрацию в режим списка (`MODE_FILTER=hostlist`), чтобы не замедлять обычные сайты;
- делает бэкап `conf.env` и откатывает изменения, если что-то пошло не так;
- в конце открывает меню для установки автозапуска.

Опции:

| Опция | Что делает |
|---|---|
| `--dir PATH` | каталог установки |
| `--strategy NAME` | сразу выставить стратегию, например `general.bat` |
| `--domains a.com,b.org` | добавить домены в `list-general.txt` |
| `--tune` | автоподбор стратегии для YouTube |
| `--desktop` | ярлык в меню приложений |
| `--nopasswd` | NOPASSWD для `nft`/`nfqws` (осторожно) |
| `--uninstall` | остановить сервис и удалить |
| `-y` | не задавать вопросов |

---

## 🪟 Windows

1. Скачай [`install-windows.bat`](https://raw.githubusercontent.com/h1nchek/zapret-installer/main/install-windows.bat) (ПКМ → «Сохранить как»).
2. Запусти, согласись на права администратора.
3. Пункт **1**: скачать и распаковать в `C:\zapret`.
4. Пункт **3**: проверь YouTube и Discord через `general.bat`. Не пошло, пробуй другие `general (ALT).bat`.
5. Пункт **2** → *Install Service*, когда нашёл рабочий вариант (автозапуск).

> Антивирус может ругаться на WinDivert (драйвер перехвата трафика). Это штатный компонент zapret, но проверяй, откуда качаешь.

---

---

## 🙏 Благодарности

- [bol-van/zapret](https://github.com/bol-van/zapret): оригинальный zapret
- [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube): сборка для Windows и стратегии
- [Sergeydigl3/zapret-discord-youtube-linux](https://github.com/Sergeydigl3/zapret-discord-youtube-linux): обёртка для Linux

---

<div align="center">

MIT © [h1nchek](https://github.com/h1nchek)

</div>
