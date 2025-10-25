# Dbg-View-2025
# Полностью самостоятельный Dbg View [2025]

### ⚙️ Функции:

**Работающее ‘приглядеться’** — `KEY_G`  

**Работающее ‘осмотреть себя’** — команда: `dbg-quickLook`  

**Работающая ‘возможность смотреть по сторонам’** - `KEY_LALT`

**Работающая задержка** — команда: `delay 'длительность', 'текст'`

lua:
```
octolib.delay.add(time, text)
```

**Octolib.notify**

lua:
```
// CLIENT
octolib.notify.show(type, text)

// SERVER
octolib.notify.send(ply, type, text)
octolib.notify.sendAll(type, text)

```

**WorkShop: https://steamcommunity.com/sharedfiles/filedetails/?id=3593320375**
