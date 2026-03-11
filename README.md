# Android Assistant

<p align="center">
  <img src="adaptive-icon-mask-applied.png" alt="Android Assistant" width="120"/>
</p>

Ferramenta desktop para gerenciamento de dispositivos Android via ADB, desenvolvida em **Delphi (FireMonkey)**.

Gerencie aplicativos, instale APKs, execute comandos shell, capture screenshots e monitore logs em tempo real — tudo em uma interface moderna e intuitiva.

---

<img width="1202" height="832" alt="thumb (1)" src="https://github.com/user-attachments/assets/6d7a06e9-03cb-4139-acbb-7d58de548b8c" />
<img width="1202" height="832" alt="thumb (2)" src="https://github.com/user-attachments/assets/7d024b57-6fc8-4c97-852e-4ab8cbd143c5" />

## Funcionalidades

### Gerenciamento de Aplicativos
- Listar todos os aplicativos instalados no dispositivo
- Filtrar apps por nome (com opção de ocultar apps do sistema)
- Visualizar informações detalhadas do pacote (`dumpsys`)
- Desinstalar aplicativos do usuário

### Instalação de APK
- Instalar APKs via seleção de arquivo ou **arrastar e soltar** (drag & drop)
- Barra de progresso e status em tempo real
- Validação automática do arquivo antes da instalação

### Ferramentas
- **Reboot:** Normal, Bootloader e Recovery
- **Screenshot:** Capturar tela do dispositivo e salvar no PC
- **Cache:** Limpar cache do sistema
- **Shell:** Executar comandos ADB/shell arbitrários com visualização da saída

### Console de Logs (Logcat)
- Streaming de logcat em tempo real
- Filtro por nível: Verbose, Debug, Info, Warning, Error
- Filtro por texto com suporte a busca
- Logs com **cores por nível** para fácil identificação
- Auto-scroll e controle de início/parada
- Otimizado para alto volume de logs (limite de 3000 linhas com limpeza automática)

---

## Screenshots

<!-- Adicione screenshots aqui -->
<!-- ![Tela Principal](screenshots/main.png) -->

---

## Tecnologias

| Componente | Tecnologia |
|---|---|
| Linguagem | Delphi (Object Pascal) |
| Framework UI | FireMonkey (FMX) |
| Renderização | Skia |
| Threading | System.Threading, TTask, TThread |
| Comunicação | ADB (Android Debug Bridge) |

---

## Arquitetura

O projeto segue uma arquitetura modular com separação de responsabilidades:

```
├── MainForm.pas          # Interface principal e coordenação
├── AppManager.pas        # Gerenciamento de aplicativos
├── APKInstaller.pas      # Instalação de APKs
├── ToolsManager.pas      # Ferramentas (reboot, screenshot, shell)
├── LogcatManager.pas     # Streaming e filtragem de logcat
├── Main.Settings.pas     # Configurações globais e caminho do ADB
└── adb/
    ├── adb.exe           # Android Debug Bridge
    └── AdbWinApi.dll     # API Windows do ADB
```

**Padrões utilizados:** Singleton (LogcatManager), Manager Pattern, Observer (ILogcatEventHandler), operações assíncronas com sincronização thread-safe.

---

## Pré-requisitos

- Windows 10/11
- Dispositivo Android com **Depuração USB** habilitada
- Cabo USB conectado ao PC

> O ADB já está incluso no projeto — não é necessário instalar separadamente.

---

## Como Usar

1. Clone o repositório
2. Abra `Project1.dproj` no **Delphi 10.4+**
3. Compile e execute (plataforma Windows 32-bit)
4. Conecte o dispositivo Android via USB com depuração habilitada
5. Clique em **Atualizar** para detectar o dispositivo

---

## Licença

Este projeto é disponibilizado para fins educacionais e de estudo.

---

<p align="center">
  Desenvolvido com Delphi FireMonkey
</p>
