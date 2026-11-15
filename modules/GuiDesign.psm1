# O visual da janela do WinForge: as cores dos temas claro e escuro, os ícones (desenhos de traço numa caixa de 24 x 24)
# e a leitura da saída das ações para o resumo da tela de execução. Só dados e lógica, sem WPF: a janela
# (WinForge.Gui.ps1) monta os controles a partir daqui, e tudo isto pode ser conferido fora do Windows.

# ---------------------------------------------------------------------------
# Temas
# ---------------------------------------------------------------------------

# Cada chave vira um pincel <Chave>Brush nos recursos da janela (o XAML usa os mesmos nomes) e também é usada pelos
# controles que o script monta. Texto sobre fundo: Text, Muted e Dim; Ok, Warn e Bad também aparecem como texto, por isso
# os tons do tema claro são mais escuros do que os do escuro. Contraste (WCAG 2.2): todo texto passa de 4,5:1 sobre a janela,
# os cartões e o fundo dos cartões sob o mouse; contornos que mostram um controle ou um estado (caixa de texto, chave
# desligada, barra de rolagem, foco) passam de 3:1. SwitchLine/SwitchKnobOff/SwitchKnobOn desenham a chave liga/desliga
# (desligada: só o contorno e a bolinha; ligada: preenchida na cor de destaque), InputLine é a borda das caixas de texto e
# ButtonLine a dos botões comuns (também acima de 3:1: mais claro, o contorno fazia o botão parecer desligado).
$script:WinForgePalettes = @{
    Light = @{
        Window = "#F5F5F7"; Sidebar = "#ECECEF"; SidebarLine = "#DCDCE1"; Card = "#FFFFFF"; CardHover = "#FAFAFC"
        Inset = "#F0F0F3"; Line = "#E3E3E8"; Text = "#1D1D1F"; Muted = "#636368"; Dim = "#66666B"
        Accent = "#0071E3"; AccentHover = "#0066CC"; AccentPressed = "#005BB5"; AccentText = "#0066CC"
        AccentCard = "#EAF2FD"; AccentLine = "#B9D3F7"; OnAccent = "#FFFFFF"; NavSelected = "#DCDCE1"
        NavHover = "#E3E3E7"; Search = "#E2E2E7"; Ok = "#1F7A35"; Warn = "#A94E07"; Bad = "#D70015"
        OkSoft = "#EBF7EE"; OkLine = "#C4E6CE"; WarnSoft = "#FFF5E6"; WarnLine = "#F3D9AE"; BadSoft = "#FDEDED"
        BadLine = "#F4C6C6"; MutedSoft = "#F2F2F5"; MutedLine = "#E3E3E8"; Track = "#E5E5EA"; Knob = "#FFFFFF"
        Shadow = "#000000"; Danger = "#D70015"; DangerSoft = "#FDEDED"; Thumb = "#86868B"; ThumbHover = "#6C6C71"
        SwitchLine = "#8A8A8E"; SwitchKnobOff = "#636368"; SwitchKnobOn = "#FFFFFF"; InputLine = "#8A8A8E"; ButtonLine = "#8A8A8E"
    }
    Dark  = @{
        Window = "#1C1C1E"; Sidebar = "#242426"; SidebarLine = "#323235"; Card = "#2C2C2E"; CardHover = "#323235"
        Inset = "#1A1A1C"; Line = "#3A3A3C"; Text = "#F5F5F7"; Muted = "#AEAEB2"; Dim = "#9C9CA1"
        Accent = "#0B6FE0"; AccentHover = "#0A62CC"; AccentPressed = "#084FA6"; AccentText = "#4DA3FF"
        AccentCard = "#1F3550"; AccentLine = "#2F5B8C"; OnAccent = "#FFFFFF"; NavSelected = "#3A3A3D"
        NavHover = "#2F2F32"; Search = "#323235"; Ok = "#30D158"; Warn = "#FF9F0A"; Bad = "#FF6961"
        OkSoft = "#1D3324"; OkLine = "#2C5537"; WarnSoft = "#382B14"; WarnLine = "#664A1C"; BadSoft = "#3A1D1D"
        BadLine = "#6A2E2E"; MutedSoft = "#3A3A3C"; MutedLine = "#48484A"; Track = "#48484A"; Knob = "#FFFFFF"
        Shadow = "#000000"; Danger = "#FF6961"; DangerSoft = "#3A1D1D"; Thumb = "#7C7C82"; ThumbHover = "#98989D"
        SwitchLine = "#8E8E93"; SwitchKnobOff = "#AEAEB2"; SwitchKnobOn = "#1C1C1E"; InputLine = "#7C7C82"; ButtonLine = "#8E8E93"
    }
}

# As 16 cores do console (Write-Host -ForegroundColor) em cada tema. No claro, "White" e "Gray" viram tons escuros:
# texto branco sobre o fundo claro dos detalhes técnicos não seria legível.
$script:WinForgeConsolePalettes = @{
    Light = @{
        Black = "#6C6C71"; DarkBlue = "#0051A8"; DarkGreen = "#1E7B34"; DarkCyan = "#00748F"; DarkRed = "#B3000F"
        DarkMagenta = "#7A3B9C"; DarkYellow = "#9A4A00"; Gray = "#3A3A3C"; DarkGray = "#6C6C71"; Blue = "#0066CC"
        Green = "#1E7B34"; Cyan = "#0071A4"; Red = "#D70015"; Magenta = "#8944AB"; Yellow = "#A15C00"
        White = "#1D1D1F"
    }
    Dark  = @{
        Black = "#8E8E93"; DarkBlue = "#409CFF"; DarkGreen = "#32D74B"; DarkCyan = "#5AC8FA"; DarkRed = "#FF6961"
        DarkMagenta = "#BF5AF2"; DarkYellow = "#FF9F0A"; Gray = "#D1D1D6"; DarkGray = "#8E8E93"; Blue = "#64A8FF"
        Green = "#30D158"; Cyan = "#64D2FF"; Red = "#FF453A"; Magenta = "#DA8FFF"; Yellow = "#FFD60A"
        White = "#FFFFFF"
    }
}


# ---------------------------------------------------------------------------
# Ícones
# ---------------------------------------------------------------------------

# Desenho próprio, em traços (comandos M L H V A C Z, separados por espaço; vírgula decimal nunca). A janela desenha
# cada um com pontas e junções arredondadas; "L x y" para um ponto quase igual vira um ponto.
$script:WinForgeIcons = @{
    "home" = "M 3.5 10.5 L 12 3.5 L 20.5 10.5 M 6 8.5 V 19.5 A 1 1 0 0 0 7 20.5 H 10 V 15 H 14 V 20.5 H 17 A 1 1 0 0 0 18 19.5 V 8.5"
    "gauge" = "M 4.6 17.5 A 8.5 8.5 0 1 1 19.4 17.5 M 12 13.5 L 15.8 8.6 M 12 13.5 L 12.01 13.5 M 7.2 12 L 6.2 11.6 M 12 6.5 L 12 5.5 M 16.8 12 L 17.8 11.6"
    "pulse" = "M 3 12.5 H 7 L 9.5 6 L 14 19 L 16.5 12.5 H 21"
    "shield" = "M 12 3.2 L 19.5 6 V 11.5 C 19.5 16 16.4 19.4 12 20.8 C 7.6 19.4 4.5 16 4.5 11.5 V 6 Z M 9 12 L 11.2 14.2 L 15.2 10.2"
    "sparkles" = "M 10.5 3.5 L 12.2 8.3 L 17 10 L 12.2 11.7 L 10.5 16.5 L 8.8 11.7 L 4 10 L 8.8 8.3 Z M 17.5 14.5 L 18.3 16.7 L 20.5 17.5 L 18.3 18.3 L 17.5 20.5 L 16.7 18.3 L 14.5 17.5 L 16.7 16.7 Z"
    "wrench" = "M 14.5 3.8 A 5 5 0 0 0 10.3 10.4 L 4.2 16.5 A 2.1 2.1 0 0 0 7.2 19.5 L 13.3 13.4 A 5 5 0 0 0 19.9 9.2 L 16.6 12.5 L 13.6 11.6 L 12.7 8.6 Z"
    "sync" = "M 19.6 10.5 A 7.8 7.8 0 0 0 5.4 7.4 M 4.5 4 V 8 H 8.5 M 4.4 13.5 A 7.8 7.8 0 0 0 18.6 16.6 M 19.5 20 V 16 H 15.5"
    "apps" = "M 4.5 4.5 H 10 V 10 H 4.5 Z M 14 4.5 H 19.5 V 10 H 14 Z M 4.5 14 H 10 V 19.5 H 4.5 Z M 14 14 H 19.5 V 19.5 H 14 Z"
    "wifi" = "M 2.8 9.2 A 13.5 13.5 0 0 1 21.2 9.2 M 5.8 12.6 A 9 9 0 0 1 18.2 12.6 M 8.9 16 A 4.6 4.6 0 0 1 15.1 16 M 12 19.4 L 12.01 19.4"
    "sliders" = "M 4 7 H 13 M 17 7 H 20 M 4 17 H 7 M 11 17 H 20 M 17 7 A 2 2 0 1 1 13 7 A 2 2 0 1 1 17 7 Z M 11 17 A 2 2 0 1 1 7 17 A 2 2 0 1 1 11 17 Z"
    "info" = "M 12 20.5 A 8.5 8.5 0 1 1 12 3.5 A 8.5 8.5 0 1 1 12 20.5 Z M 12 11 V 16.5 M 12 7.8 L 12.01 7.8"
    "search" = "M 10.5 16.5 A 6 6 0 1 1 10.5 4.5 A 6 6 0 1 1 10.5 16.5 Z M 15 15 L 19.5 19.5"
    "check" = "M 5 12.5 L 10 17.5 L 19 7"
    "check-circle" = "M 12 20.5 A 8.5 8.5 0 1 1 12 3.5 A 8.5 8.5 0 1 1 12 20.5 Z M 8.2 12.3 L 10.9 15 L 16 9.4"
    "warning" = "M 12 4 L 20.8 19.2 H 3.2 Z M 12 10 V 14 M 12 16.9 L 12.01 16.9"
    "error-circle" = "M 12 20.5 A 8.5 8.5 0 1 1 12 3.5 A 8.5 8.5 0 1 1 12 20.5 Z M 9 9 L 15 15 M 15 9 L 9 15"
    "minus-circle" = "M 12 20.5 A 8.5 8.5 0 1 1 12 3.5 A 8.5 8.5 0 1 1 12 20.5 Z M 8.5 12 H 15.5"
    "x" = "M 6.5 6.5 L 17.5 17.5 M 17.5 6.5 L 6.5 17.5"
    "chevron-right" = "M 9.5 6 L 15.5 12 L 9.5 18"
    "chevron-down" = "M 6 9.5 L 12 15.5 L 18 9.5"
    "chevron-up" = "M 6 14.5 L 12 8.5 L 18 14.5"
    "arrow-left" = "M 19 12 H 5 M 11 6 L 5 12 L 11 18"
    "external" = "M 14 4 H 20 V 10 M 20 4 L 11.5 12.5 M 18 14 V 19 A 1 1 0 0 1 17 20 H 5 A 1 1 0 0 1 4 19 V 7 A 1 1 0 0 1 5 6 H 10"
    "folder" = "M 3.5 7 A 1.5 1.5 0 0 1 5 5.5 H 9.5 L 11.5 7.5 H 19 A 1.5 1.5 0 0 1 20.5 9 V 17.5 A 1.5 1.5 0 0 1 19 19 H 5 A 1.5 1.5 0 0 1 3.5 17.5 Z"
    "copy" = "M 9 8.5 H 18.5 V 20 H 9 Z M 15 8.5 V 4 H 5.5 V 15.5 H 9"
    "download" = "M 12 4 V 15 M 7.5 10.5 L 12 15 L 16.5 10.5 M 5 19.5 H 19"
    "upload" = "M 12 15 V 4 M 7.5 8.5 L 12 4 L 16.5 8.5 M 5 19.5 H 19"
    "refresh" = "M 19.5 12 A 7.5 7.5 0 1 1 17.2 6.6 M 19.5 4 V 8.5 H 15"
    "stop" = "M 7.5 6.5 H 16.5 A 1 1 0 0 1 17.5 7.5 V 16.5 A 1 1 0 0 1 16.5 17.5 H 7.5 A 1 1 0 0 1 6.5 16.5 V 7.5 A 1 1 0 0 1 7.5 6.5 Z"
    "play" = "M 8 5.5 L 18.5 12 L 8 18.5 Z"
    "clock" = "M 12 20.5 A 8.5 8.5 0 1 1 12 3.5 A 8.5 8.5 0 1 1 12 20.5 Z M 12 7.5 V 12 L 15 14"
    "history" = "M 4.3 12 A 7.7 7.7 0 1 0 6.6 6.6 L 4.3 8.9 M 4.3 4.6 V 8.9 H 8.6 M 12 8 V 12 L 14.8 13.8"
    "monitor" = "M 4.5 4.5 H 19.5 A 1 1 0 0 1 20.5 5.5 V 15 A 1 1 0 0 1 19.5 16 H 4.5 A 1 1 0 0 1 3.5 15 V 5.5 A 1 1 0 0 1 4.5 4.5 Z M 8.5 20 H 15.5 M 12 16 V 20"
    "disk" = "M 4 14.5 H 20 V 19 A 1 1 0 0 1 19 20 H 5 A 1 1 0 0 1 4 19 Z M 4 14.5 L 6.3 5.3 A 1 1 0 0 1 7.3 4.5 H 16.7 A 1 1 0 0 1 17.7 5.3 L 20 14.5 M 16.5 17.2 L 16.51 17.2"
    "battery" = "M 4.5 7.5 H 17 A 1 1 0 0 1 18 8.5 V 15.5 A 1 1 0 0 1 17 16.5 H 4.5 A 1 1 0 0 1 3.5 15.5 V 8.5 A 1 1 0 0 1 4.5 7.5 Z M 20.5 10.5 V 13.5 M 6.5 10.5 V 13.5 M 9.5 10.5 V 13.5"
    "user" = "M 12 11.5 A 3.75 3.75 0 1 1 12 4 A 3.75 3.75 0 1 1 12 11.5 Z M 5 20 C 5.8 16.7 8.4 14.8 12 14.8 C 15.6 14.8 18.2 16.7 19 20"
    "calendar" = "M 5.5 6 H 18.5 A 1 1 0 0 1 19.5 7 V 19 A 1 1 0 0 1 18.5 20 H 5.5 A 1 1 0 0 1 4.5 19 V 7 A 1 1 0 0 1 5.5 6 Z M 4.5 10.5 H 19.5 M 8.5 3.8 V 7.5 M 15.5 3.8 V 7.5"
    "power" = "M 12 3.5 V 11 M 7.2 6.4 A 7.5 7.5 0 1 0 16.8 6.4"
    "lock" = "M 6.5 10.5 H 17.5 A 1 1 0 0 1 18.5 11.5 V 19 A 1 1 0 0 1 17.5 20 H 6.5 A 1 1 0 0 1 5.5 19 V 11.5 A 1 1 0 0 1 6.5 10.5 Z M 8.5 10.5 V 7.5 A 3.5 3.5 0 0 1 15.5 7.5 V 10.5"
    "list" = "M 9 6.5 H 20 M 9 12 H 20 M 9 17.5 H 20 M 4.5 6.5 L 4.51 6.5 M 4.5 12 L 4.51 12 M 4.5 17.5 L 4.51 17.5"
    "bolt" = "M 13 3 L 5.5 13.5 H 11.5 L 10.5 21 L 18.5 10.5 H 12.5 Z"
    "package" = "M 12 3.2 L 19.8 7.6 V 16.4 L 12 20.8 L 4.2 16.4 V 7.6 Z M 4.2 7.6 L 12 12 L 19.8 7.6 M 12 12 V 20.8"
    "trash" = "M 4.5 6.5 H 19.5 M 9.5 6.5 V 4.5 H 14.5 V 6.5 M 6.5 6.5 L 7.4 19.1 A 1 1 0 0 0 8.4 20 H 15.6 A 1 1 0 0 0 16.6 19.1 L 17.5 6.5 M 10 10.5 V 16 M 14 10.5 V 16"
    "globe" = "M 12 20.5 A 8.5 8.5 0 1 1 12 3.5 A 8.5 8.5 0 1 1 12 20.5 Z M 3.5 12 H 20.5 M 12 3.5 C 9.5 6 8.6 9 8.6 12 C 8.6 15 9.5 18 12 20.5 C 14.5 18 15.4 15 15.4 12 C 15.4 9 14.5 6 12 3.5 Z"
    "document" = "M 6.5 3.5 H 14 L 18.5 8 V 19.5 A 1 1 0 0 1 17.5 20.5 H 6.5 A 1 1 0 0 1 5.5 19.5 V 4.5 A 1 1 0 0 1 6.5 3.5 Z M 14 3.5 V 8 H 18.5 M 8.8 12.5 H 15.2 M 8.8 16 H 15.2"
    "cpu" = "M 7.5 7 H 16.5 A 0.5 0.5 0 0 1 17 7.5 V 16.5 A 0.5 0.5 0 0 1 16.5 17 H 7.5 A 0.5 0.5 0 0 1 7 16.5 V 7.5 A 0.5 0.5 0 0 1 7.5 7 Z M 10 10 H 14 V 14 H 10 Z M 10 4 V 7 M 14 4 V 7 M 10 17 V 20 M 14 17 V 20 M 4 10 H 7 M 4 14 H 7 M 17 10 H 20 M 17 14 H 20"
    "undo" = "M 9 14 L 4.5 9.5 L 9 5 M 4.5 9.5 H 14.5 A 5.5 5.5 0 0 1 14.5 20.5 H 11"
    "restore" = "M 4.3 12 A 7.7 7.7 0 1 0 6.6 6.6 L 4.3 8.9 M 4.3 4.6 V 8.9 H 8.6"
    "speed" = "M 4.6 17.5 A 8.5 8.5 0 1 1 19.4 17.5 M 12 13.5 L 15.8 8.6"
    "rocket" = "M 12 3 C 15.6 5.2 16.9 8.9 16.2 13.4 L 14.6 16.2 H 9.4 L 7.8 13.4 C 7.1 8.9 8.4 5.2 12 3 Z M 12 11.2 A 1.8 1.8 0 1 1 12 7.6 A 1.8 1.8 0 1 1 12 11.2 Z M 7.8 13.4 L 5.2 15.8 L 5.6 18.6 L 9.4 16.2 M 16.2 13.4 L 18.8 15.8 L 18.4 18.6 L 14.6 16.2 M 10.6 19.2 L 12 21.2 L 13.4 19.2"
    "link" = "M 10 14 L 14 10 M 8.5 11 L 6.7 12.8 A 3.5 3.5 0 0 0 11.2 17.3 L 13 15.5 M 15.5 13 L 17.3 11.2 A 3.5 3.5 0 0 0 12.8 6.7 L 11 8.5"
    "key" = "M 8 16 A 3.5 3.5 0 1 1 8 9 A 3.5 3.5 0 1 1 8 16 Z M 11.5 12.5 H 20 M 17 12.5 V 15.5 M 20 12.5 V 15"
    "bell" = "M 6 16.5 V 11 A 6 6 0 0 1 18 11 V 16.5 L 19.5 18 H 4.5 Z M 10 20.5 H 14"
    "flag" = "M 6 20.5 V 4 M 6 4.5 H 17.5 L 15.2 8.5 L 17.5 12.5 H 6"
    "terminal" = "M 4.5 4.5 H 19.5 A 1 1 0 0 1 20.5 5.5 V 18.5 A 1 1 0 0 1 19.5 19.5 H 4.5 A 1 1 0 0 1 3.5 18.5 V 5.5 A 1 1 0 0 1 4.5 4.5 Z M 7.5 9 L 10.5 12 L 7.5 15 M 12.5 15 H 16.5"
    "dots" = "M 6 12 L 6.01 12 M 12 12 L 12.01 12 M 18 12 L 18.01 12"
    "palette" = "M 12 3.5 C 7.3 3.5 3.5 7.3 3.5 12 C 3.5 16.7 7.3 20.5 12 20.5 C 13.2 20.5 13.9 19.7 13.9 18.7 C 13.9 17.6 13 17.2 13 16.2 C 13 15.2 13.8 14.5 14.8 14.5 H 16.8 C 18.9 14.5 20.5 12.9 20.5 10.8 C 20.5 6.8 16.7 3.5 12 3.5 Z M 7.8 12.2 L 7.81 12.2 M 9.6 8.2 L 9.61 8.2 M 14.2 7.6 L 14.21 7.6 M 17 10.6 L 17.01 10.6"
    "keyboard" = "M 4.5 6.5 H 19.5 A 1 1 0 0 1 20.5 7.5 V 16.5 A 1 1 0 0 1 19.5 17.5 H 4.5 A 1 1 0 0 1 3.5 16.5 V 7.5 A 1 1 0 0 1 4.5 6.5 Z M 7 10 L 7.01 10 M 10.3 10 L 10.31 10 M 13.7 10 L 13.71 10 M 17 10 L 17.01 10 M 8.5 14 H 15.5"
    "admin" = "M 12 3.2 L 19.5 6 V 11.5 C 19.5 16 16.4 19.4 12 20.8 C 7.6 19.4 4.5 16 4.5 11.5 V 6 Z"
}

# O ícone de cada página, de cada item da navegação e de cada cartão do Início ("fact.<id>"). Item sem ícone próprio usa o
# da página dele.
$script:WinForgeIconNames = @{
    "home" = "home"; "maintenance" = "gauge"; "diagnostics" = "pulse"; "security" = "shield"; "cleanup" = "sparkles"
    "repair" = "wrench"; "updates" = "sync"; "performance" = "rocket"; "software" = "apps"; "network" = "wifi"; "tweaks" = "sliders"; "personalize" = "palette"; "app" = "info"
    "search" = "search"

    "maintenance.recommended" = "gauge"; "maintenance.restore-point" = "flag"; "maintenance.restore" = "restore"
    "maintenance.schedule" = "calendar"; "maintenance.history" = "list"
    "maintenance.task-scheduler" = "clock"; "maintenance.checkup" = "check-circle"; "maintenance.changes" = "undo"

    "diagnostics.about" = "monitor"; "diagnostics.disks" = "disk"; "diagnostics.disk-health" = "pulse"; "diagnostics.battery" = "battery"
    "diagnostics.events" = "warning"; "diagnostics.devices" = "cpu"; "diagnostics.startup" = "clock"
    "diagnostics.pending-reboot" = "power"; "diagnostics.report" = "document"; "diagnostics.device-manager" = "sliders"
    "diagnostics.reliability" = "history"; "diagnostics.windows-support" = "calendar"

    "security.status" = "shield"; "security.audit" = "list"; "security.signatures" = "download"; "security.scan" = "search"
    "security.full-scan" = "disk"; "security.folder-scan" = "folder"; "security.windows-security" = "lock"

    "cleanup.quick" = "bolt"; "cleanup.space" = "disk"; "cleanup.custom" = "list"
    "cleanup.recycle-bin" = "trash"; "cleanup.downloads" = "download"
    "cleanup.components" = "package"; "cleanup.storage" = "sliders"; "cleanup.shortcuts" = "link"; "cleanup.duplicates" = "copy"
    "cleanup.leftovers" = "folder"; "cleanup.registry" = "key"; "cleanup.wipe-free" = "lock"

    "performance.boost" = "rocket"; "performance.processes" = "pulse"; "performance.memory" = "cpu"; "performance.startup" = "power"; "performance.task-manager" = "monitor"

    "repair.dism-sfc" = "wrench"; "repair.dism" = "package"; "repair.sfc" = "document"; "repair.chkdsk" = "disk"
    "repair.device-scan" = "search"; "repair.optimize" = "speed"; "repair.system-restore" = "history"; "repair.recovery" = "restore"

    "updates.install" = "download"; "updates.winget" = "package"; "updates.windows" = "sync"; "updates.optional" = "list"
    "updates.store" = "apps"; "updates.drivers" = "cpu"; "updates.vendor-tools" = "search"; "updates.repair" = "wrench"

    "software.essentials" = "package"; "software.find" = "search"; "software.list" = "list"; "software.uninstall" = "trash"
    "software.installed-apps" = "apps"; "software.programs-features" = "folder"; "software.remove-apps" = "minus-circle"
    "software.startup-manager" = "power"; "software.startup" = "play"; "software.features" = "sliders"
    "software.backup" = "upload"; "software.restore" = "download"

    "network.info" = "info"; "network.ping" = "pulse"; "network.speed" = "speed"; "network.wifi-report" = "document"
    "network.repair" = "wrench"; "network.dns" = "globe"; "network.dns-undo" = "undo"

    "tweaks.recommended" = "sparkles"; "tweaks.profiles" = "list"; "tweaks.restore-point" = "restore"; "tweaks.export" = "upload"
    "tweaks.import" = "download"; "tweaks.revert-all" = "undo"; "tweaks.keyboard-language" = "keyboard"; "tweaks.notifications" = "bell"
    "personalize.accent-color" = "palette"; "personalize.lock-screen" = "lock"; "personalize.settings" = "monitor"

    "app.about" = "info"; "app.update" = "download"; "app.shortcut" = "link"; "app.logs" = "folder"
    "app.monitor" = "bell"; "app.catalog" = "refresh"

    "fact.windows" = "monitor"; "fact.disk" = "disk"; "fact.reboot" = "power"
    "fact.maintenance" = "history"; "fact.security" = "shield"; "fact.battery" = "battery"
}


function Get-WinForgePalette {
    # As cores de um tema (cópia: quem altera não muda a tabela).
    param ([ValidateSet("Light", "Dark")][string]$Name = "Light")

    return $script:WinForgePalettes[$Name].Clone()
}


function Get-WinForgeConsolePalette {
    param ([ValidateSet("Light", "Dark")][string]$Name = "Light")

    return $script:WinForgeConsolePalettes[$Name].Clone()
}


function Get-WinForgeLevelColors {
    # As cores de cada nível de resultado (Ok, Warn, Bad, Muted) num tema: Dot é a cor do texto e do ícone, Back o fundo
    # suave e Line o contorno; Icon é o ícone do resultado.
    param ([Parameter(Mandatory)][hashtable]$Theme)

    return @{
        Ok    = @{ Dot = $Theme.Ok; Back = $Theme.OkSoft; Line = $Theme.OkLine; Icon = "check-circle" }
        Warn  = @{ Dot = $Theme.Warn; Back = $Theme.WarnSoft; Line = $Theme.WarnLine; Icon = "warning" }
        Bad   = @{ Dot = $Theme.Bad; Back = $Theme.BadSoft; Line = $Theme.BadLine; Icon = "error-circle" }
        Muted = @{ Dot = $Theme.Dim; Back = $Theme.MutedSoft; Line = $Theme.MutedLine; Icon = "minus-circle" }
    }
}


function Get-WinForgeThemePreference {
    # O tema escolhido em Sobre o WinForge > Aparência: System (como o Windows, o padrão), Light ou Dark.
    $value = [string](Get-WinForgeSetting -Name "Theme" -Default "System")

    if ($value -eq "Light" -or $value -eq "Dark") { return $value }

    return "System"
}


function Resolve-WinForgeTheme {
    # O tema a usar: o escolhido pela pessoa ou, em "como o Windows", o dos aplicativos do Windows (claro, se não der
    # para saber).
    param (
        [string]$Preference = "System",
        [string]$SystemTheme = "Light"
    )

    if ($Preference -eq "Light" -or $Preference -eq "Dark") { return $Preference }

    if ($SystemTheme -eq "Dark") { return "Dark" }

    return "Light"
}


function ConvertTo-WinForgeColorRef {
    # "#RRGGBB" no formato COLORREF do Windows (0x00BBGGRR), para a cor da barra de título.
    param ([Parameter(Mandatory)][string]$Hex)

    if ($Hex -notmatch '^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$') { throw "Cor inválida: $Hex" }

    $r = [Convert]::ToInt32($Matches[1], 16)
    $g = [Convert]::ToInt32($Matches[2], 16)
    $b = [Convert]::ToInt32($Matches[3], 16)

    return [int]($r + ($g * 256) + ($b * 65536))
}


function Get-WinForgeIconData {
    # O desenho de um ícone (texto de geometria do WPF). Nome desconhecido vira o de reticências, para nunca faltar ícone.
    param ([Parameter(Mandatory)][string]$Name)

    if ($script:WinForgeIcons.ContainsKey($Name)) { return [string]$script:WinForgeIcons[$Name] }

    return [string]$script:WinForgeIcons["dots"]
}


function Get-WinForgeIconNames {
    return @($script:WinForgeIcons.Keys | Sort-Object)
}


function Get-WinForgeLogoDrawing {
    # O desenho de assets\WinForge.svg, para a janela desenhar o ícone quando o .ico não está na pasta: o quadrado grafite
    # numa caixa de 1024 e a bigorna (branca, de face azul), cujos traços o SVG reduz com scale(.9) e desloca com
    # translate(-36 -88). Os traços são os mesmos do SVG, com o L da segunda reta escrito por extenso.
    return [PSCustomObject]@{
        Box        = 1024
        TileColor  = "#17191F"
        TileX      = 32
        TileSize   = 960
        TileRadius = 208
        Scale      = 0.9
        OffsetX    = -36
        OffsetY    = -88
        Parts      = @(
            [PSCustomObject]@{ Color = "#5B91FF"; Data = "M731 489 L765 458 Q769 454 777 454H965Q975 454 975 464V489Z" },
            [PSCustomObject]@{ Color = "#F3F5F7"; Data = "M242 506H465L469 497Q472 489 481 489H975V564Q975 575 964 575C883 577 800 613 771 671C735 744 782 775 874 795L933 860Q940 877 926 877H386Q370 877 377 861L438 795C513 778 552 752 552 709C552 666 516 633 469 633H439Q432 633 425 629L245 518Q231 508 242 506Z" }
        )
    }
}


function Get-WinForgeIconName {
    # O ícone de uma página, de um item ("pagina.item") ou de um cartão do Início ("fact.<id>"). Um resultado da busca que
    # leva a uma página ("search.page.<página>", ou a uma parte dela) tem o ícone da página; um ajuste ("search.tweak.<página>.<ajuste>"), o da página dele.
    param ([Parameter(Mandatory)][AllowEmptyString()][string]$Id)

    if ($Id.StartsWith("search.page.")) { $Id = ($Id.Substring(12) -split '\.', 2)[0] }
    elseif ($Id.StartsWith("search.tweak.")) { $Id = ($Id.Substring(13) -split '\.', 2)[0] }

    if ($script:WinForgeIconNames.ContainsKey($Id)) { return [string]$script:WinForgeIconNames[$Id] }

    $page = ($Id -split '\.', 2)[0]

    if ($script:WinForgeIconNames.ContainsKey($page)) { return [string]$script:WinForgeIconNames[$page] }

    return "dots"
}


function Get-WinForgeHealthHeadline {
    # A frase grande da nota de saúde no Início. Se parte do que entra na nota não pôde ser lida, uma nota alta não
    # garante nada sobre essa parte: a frase fica mais modesta ("parece bem") e o resumo embaixo diz o que faltou.
    param ($Health)

    if ($null -eq $Health) { return "" }

    $unread = @(Get-WinForgeJsonValue -Object $Health -Name "Unread" -Default @())

    if ($unread.Count -gt 0 -and [string]$Health.Label -in @("Ótima", "Boa", "Incompleta")) { return "Seu PC parece bem" }

    switch ([string]$Health.Label) {
        "Ótima" { return "Seu PC está em ótima forma" }
        "Boa" { return "Seu PC está bem" }
        "Pede atenção" { return "Seu PC pede atenção" }
        "Crítica" { return "Seu PC precisa de cuidados" }
    }

    return "Saúde do PC: $($Health.Label)"
}


# ---------------------------------------------------------------------------
# Resumo da execução (o que a tela mostra sem os detalhes técnicos)
# ---------------------------------------------------------------------------

function Get-WinForgeActivityEntry {
    <#
    Uma linha da saída que vale para o resumo da execução: as mensagens de estado do WinForge ("[OK] texto", "[!]",
    "[X]", "[i]", "[..]"), as etapas ("[>] título") e as etapas ignoradas de uma tabela de resultados ("[-]"). Devolve
    Kind (Ok | Warn | Bad | Info | Run | Step | Skip) e o texto sem a marca, ou $null para as demais linhas (tabelas,
    saída de programas, linhas em branco).
    #>
    param ([AllowEmptyString()][string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }

    # -cmatch: as marcas são exatamente estas ("[ok]" ou "[I]" não são mensagens do WinForge).
    if ($Text -cnotmatch '^\s*\[(OK|!|X|i|\.\.|>|-)\]\s+(\S.*?)\s*$') { return $null }

    $kind = switch -CaseSensitive ($Matches[1]) {
        "OK" { "Ok" }
        "!" { "Warn" }
        "X" { "Bad" }
        "i" { "Info" }
        ".." { "Run" }
        ">" { "Step" }
        "-" { "Skip" }
    }

    return [PSCustomObject]@{ Kind = $kind; Text = $Matches[2] }
}


function Get-WinForgeFactEntry {
    <#
    Uma linha "rótulo : valor" do WinForge (Write-WinForgeKeyValue: dois espaços, o rótulo e " : " em cinza-escuro e o
    valor), que entra no resumo da execução como um fato: o espaço livre depois de uma limpeza, a próxima execução de uma
    tarefa, a duração de uma etapa. Colors são as cores dos pedaços da linha, na ordem; a cor separa uma linha do
    WinForge da saída de um programa que por acaso tenha " : " (o ipconfig, por exemplo). Devolve Kind = "Fact", Label,
    Value, Text ("rótulo: valor") e Level (a cor do valor: Green = Ok, Yellow = Warn, Red = Bad, as outras = Normal), ou
    $null.
    #>
    param (
        [AllowEmptyString()][string]$Text,
        [string[]]$Colors = @()
    )

    if ([string]::IsNullOrWhiteSpace($Text) -or @($Colors).Count -lt 4) { return $null }
    if ($Colors[1] -ne "DarkGray" -or $Colors[2] -ne "DarkGray") { return $null }
    if ($Text -notmatch '^  (\S.*?)\s* : (.*\S)\s*$') { return $null }

    $label = $Matches[1].Trim()
    $value = $Matches[2].Trim()

    if ($label.Length -gt 60) { return $null }

    $level = switch ([string]$Colors[3]) { "Green" { "Ok" } "Yellow" { "Warn" } "Red" { "Bad" } default { "Normal" } }

    return [PSCustomObject]@{ Kind = "Fact"; Label = $label; Value = $value; Text = "${label}: $value"; Level = $level }
}


function Get-WinForgeOverallProgress {
    <#
    O andamento da execução inteira, em porcentagem (com uma casa), na etapa Index de Total: as etapas anteriores já
    feitas mais Fraction (de 0 a 1) da etapa atual, que a ferramenta da vez informa. A barra de uma execução de 22 etapas
    não volta a zero a cada etapa. 0 sem etapas.
    #>
    param (
        [int]$Index,
        [int]$Total,
        [double]$Fraction = 0.0
    )

    if ($Total -le 0) { return 0.0 }
    if ([double]::IsNaN($Fraction) -or [double]::IsInfinity($Fraction)) { $Fraction = 0.0 }

    $part = [Math]::Max(0.0, [Math]::Min(1.0, $Fraction))
    $done = [Math]::Max(0, [Math]::Min($Total, $Index - 1))

    return [Math]::Min(100.0, [Math]::Round(100.0 * ($done + $part) / $Total, 1))
}


function Get-WinForgeSummaryMaxHeight {
    <#
    A altura máxima do resumo quando ele é o conteúdo da tela de execução: do topo dele até o cartão dos detalhes
    técnicos, menos o que fica embaixo dele no cartão do resultado (20 de margem interna, 1 de borda), o espaço entre os
    cartões (14) e 2 de folga. Top: onde o resumo começa, medido do alto da tela de execução. Nunca menos que $Minimum, a
    altura de sempre do resumo (numa janela muito baixa, ou antes de a tela ter tamanho).
    #>
    param (
        [double]$ViewHeight,
        [double]$Top,
        [double]$DetailsHeight,
        [double]$Minimum = 232
    )

    $available = $ViewHeight - $Top - $DetailsHeight - 37

    if ([double]::IsNaN($available) -or [double]::IsInfinity($available) -or $available -lt $Minimum) {
        return $Minimum
    }

    return [Math]::Floor($available)
}


function Test-WinForgeRuleLine {
    # A linha de traços que o WinForge desenha embaixo do título de uma seção.
    param ([AllowEmptyString()][string]$Text)

    return ($Text -match ('^\s*[' + [char]0x2500 + [char]0x2501 + '\-=]{4,}\s*$'))
}


function Get-WinForgeSectionTitle {
    <#
    O título de uma seção (Write-WinForgeSection): dois espaços e o texto em ciano, numa linha curta. Só é confirmado como
    seção quando a linha seguinte é a de traços (Test-WinForgeRuleLine). Devolve o título ou $null.
    #>
    param (
        [AllowEmptyString()][string]$Text,
        [string]$Color = ""
    )

    if ($Color -ne "Cyan") { return $null }

    if ($Text -notmatch '^ {1,4}(\S.*?)\s*$') { return $null }

    $title = $Matches[1]

    if ($title.StartsWith("[") -or $title.Length -gt 90) { return $null }

    return $title
}


Export-ModuleMember -Function *
