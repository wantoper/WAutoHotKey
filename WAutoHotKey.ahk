; ============================================
;  WAutoHotKey - 窗口跳转管理工具
;  AHK v2  |  热键切换窗口 + 配置管理 UI + 窗口探测器
; ============================================

#SingleInstance Force
SetTitleMatchMode 2  ; 标题包含匹配

; ========== 全局变量 ==========
configPath := A_ScriptDir "\config.ini"
rules := []            ; 规则数组: {hotkey, name, match, exclude, enabled}
registered := Map()    ; 已注册热键映射: hotkeyStr -> callback
mainGui := ""
lvMain := ""
detectorGui := ""
lvDetector := ""

; ========== 启动流程 ==========
LoadConfig()
RegisterHotkeys()
SetupTray()
TrayTip("WAutoHotKey", "已加载 " rules.Length " 条热键规则", , 1500)

; ================================================================
;  配置管理
; ================================================================

LoadConfig() {
    global rules, configPath
    rules := []

    if !FileExist(configPath) {
        CreateDefaultConfig()
        return
    }

    try {
        sections := IniRead(configPath)
        for section in sections {
            if (SubStr(section, 1, 4) != "Rule")
                continue
            hotkey  := IniRead(configPath, section, "hotkey", "")
            name    := IniRead(configPath, section, "name", "")
            match   := IniRead(configPath, section, "match", "")
            exclude := IniRead(configPath, section, "exclude", "")
            enabled := IniRead(configPath, section, "enabled", "1") = "1"
            if (hotkey != "" && match != "")
                rules.Push({hotkey: hotkey, name: name, match: match, exclude: exclude, enabled: enabled})
        }
    } catch as e {
        MsgBox("配置文件读取失败: " e.Message, "WAutoHotKey 错误", "IconError T10")
    }
}

SaveConfig() {
    global rules, configPath

    ; 清除旧规则 section
    try {
        sections := IniRead(configPath)
        for section in sections
            if (SubStr(section, 1, 4) = "Rule")
                IniDelete(configPath, section)
    }

    ; 写入新规则
    for index, rule in rules {
        section := "Rule" (index - 1)
        IniWrite(rule.hotkey,  configPath, section, "hotkey")
        IniWrite(rule.name,    configPath, section, "name")
        IniWrite(rule.match,   configPath, section, "match")
        IniWrite(rule.exclude, configPath, section, "exclude")
        IniWrite(rule.enabled ? "1" : "0", configPath, section, "enabled")
    }
}

CreateDefaultConfig() {
    global rules
    rules := [
        {hotkey: "^!vkC0", name: "PyCharm 终端",  match: "终端 ahk_exe jetbrains_client64.exe", exclude: "", enabled: true},
        {hotkey: "^!1",     name: "PyCharm 主窗口", match: "ahk_exe jetbrains_client64.exe", exclude: "i)^(终端|提交|设置|运行|调试|查找|搜索|版本|变更|Commit|Run|Debug|Settings|Terminal)", enabled: true},
        {hotkey: "^!2",     name: "Xshell",         match: "ahk_exe Xshell.exe", exclude: "", enabled: true},
        {hotkey: "^!3",     name: "Chrome",         match: "ahk_exe chrome.exe", exclude: "i)DevTools|开发者工具", enabled: true}
    ]
    SaveConfig()
}

; ================================================================
;  热键管理
; ================================================================

RegisterHotkeys() {
    global rules, registered

    ; 注销所有旧热键
    for hotkeyStr in registered {
        try Hotkey(hotkeyStr, , "Off")
    }
    registered := Map()

    ; 注册新热键
    for index, rule in rules {
        if (!rule.enabled || rule.hotkey = "")
            continue
        try {
            callback := ToggleWindow.Bind(rule)
            Hotkey(rule.hotkey, callback, "On")
            registered[rule.hotkey] := callback
        } catch as e {
            MsgBox("热键注册失败: " rule.hotkey "`n" e.Message, "WAutoHotKey 警告", "IconWarning T10")
        }
    }
}

ReloadAll() {
    LoadConfig()
    RegisterHotkeys()
    RefreshListView()
    TrayTip("WAutoHotKey", "配置已重新加载，共 " rules.Length " 条规则", , 1500)
}

; ================================================================
;  核心功能: ToggleWindow
; ================================================================

ToggleWindow(rule, ThisHotkey := "") {
    targetHwnd := 0

    ; 定位目标窗口句柄
    if (rule.exclude != "") {
        try {
            wins := WinGetList(rule.match)
            for hwnd in wins {
                t := WinGetTitle("ahk_id " hwnd)
                if (t != "" && !RegExMatch(t, rule.exclude)) {
                    targetHwnd := hwnd
                    break
                }
            }
        }
    } else {
        targetHwnd := WinExist(rule.match)
    }

    if (!targetHwnd)
        return

    ; Toggle: 已激活则最小化, 否则激活
    if (WinExist("A") = targetHwnd)
        WinMinimize("ahk_id " targetHwnd)
    else
        WinActivate("ahk_id " targetHwnd)
}

; ================================================================
;  托盘菜单
; ================================================================

SetupTray() {
    A_TrayMenu.Delete()
    A_TrayMenu.Tip := "WAutoHotKey - 窗口跳转管理"
    A_TrayMenu.Add("配置管理", (*) => ShowMainGui())
    A_TrayMenu.Add("窗口探测器", (*) => ShowDetectorGui())
    A_TrayMenu.Add()
    A_TrayMenu.Add("重新加载配置", (*) => ReloadAll())
    A_TrayMenu.Add("退出", (*) => ExitApp())
}

; ================================================================
;  主配置 UI
; ================================================================

ShowMainGui() {
    global mainGui, lvMain

    if (mainGui != "") {
        mainGui.Show()
        RefreshListView()
        return
    }

    mainGui := Gui(, "WAutoHotKey - 窗口跳转配置")
    mainGui.SetFont("s10", "Microsoft YaHei UI")
    mainGui.OnEvent("Close", (*) => mainGui.Hide())

    ; ListView
    lvMain := mainGui.AddListView("x10 y10 w720 h340", ["启用", "热键", "名称", "匹配条件", "排除正则"])
    lvMain.ModifyCol(1, 50)
    lvMain.ModifyCol(2, 100)
    lvMain.ModifyCol(3, 120)
    lvMain.ModifyCol(4, 240)
    lvMain.ModifyCol(5, 190)
    lvMain.OnEvent("DoubleClick", (*) => EditSelected())

    ; 按钮行
    mainGui.AddButton("x10 y360 w75 h30", "新增").OnEvent("Click", (*) => AddNew())
    mainGui.AddButton("x90 y360 w75 h30", "编辑").OnEvent("Click", (*) => EditSelected())
    mainGui.AddButton("x170 y360 w75 h30", "删除").OnEvent("Click", (*) => DeleteSelected())
    mainGui.AddButton("x250 y360 w75 h30", "上移").OnEvent("Click", (*) => MoveSelected(-1))
    mainGui.AddButton("x330 y360 w75 h30", "下移").OnEvent("Click", (*) => MoveSelected(1))
    mainGui.AddButton("x430 y360 w110 h30", "窗口探测器").OnEvent("Click", (*) => ShowDetectorGui())
    mainGui.AddButton("x560 y360 w80 h30", "保存并生效").OnEvent("Click", (*) => SaveAndApply())
    mainGui.AddButton("x650 y360 w80 h30", "关闭").OnEvent("Click", (*) => mainGui.Hide())

    mainGui.Show("w740 h405")
    RefreshListView()
}

RefreshListView() {
    global lvMain, rules
    if (lvMain = "")
        return
    lvMain.Delete()
    for index, rule in rules {
        lvMain.Add(, rule.enabled ? "✓" : "", rule.hotkey, rule.name, rule.match, rule.exclude)
    }
}

GetSelectedIndex() {
    global lvMain
    if (lvMain = "")
        return 0
    return lvMain.GetNext(0, "S")
}

AddNew() {
    global rules
    newRule := {hotkey: "", name: "新窗口", match: "", exclude: "", enabled: true}
    if (ShowEditDialog(newRule)) {
        rules.Push(newRule)
        RefreshListView()
    }
}

EditSelected() {
    global rules
    idx := GetSelectedIndex()
    if (idx = 0) {
        MsgBox("请先选择一条规则", "提示", "T3")
        return
    }
    rule := rules[idx]
    edit := {hotkey: rule.hotkey, name: rule.name, match: rule.match, exclude: rule.exclude, enabled: rule.enabled}
    if (ShowEditDialog(edit)) {
        rules[idx] := edit
        RefreshListView()
    }
}

DeleteSelected() {
    global rules
    idx := GetSelectedIndex()
    if (idx = 0) {
        MsgBox("请先选择一条规则", "提示", "T3")
        return
    }
    if (MsgBox("确定删除规则: " rules[idx].name " ?", "确认删除", "YesNo IconQuestion") = "Yes") {
        rules.RemoveAt(idx)
        RefreshListView()
    }
}

MoveSelected(direction) {
    global rules, lvMain
    idx := GetSelectedIndex()
    if (idx = 0)
        return
    newIdx := idx + direction
    if (newIdx < 1 || newIdx > rules.Length)
        return
    temp := rules[idx]
    rules[idx] := rules[newIdx]
    rules[newIdx] := temp
    RefreshListView()
    lvMain.Modify(newIdx, "Select")
}

SaveAndApply() {
    SaveConfig()
    RegisterHotkeys()
    TrayTip("WAutoHotKey", "配置已保存，热键已更新", , 1500)
}

; ================================================================
;  编辑规则对话框
; ================================================================

ShowEditDialog(rule) {
    dlg := Gui(, "编辑规则")
    dlg.SetFont("s10", "Microsoft YaHei UI")

    dlg.AddText("x10 y13", "热键:")
    ctlHotkey := dlg.AddEdit("x70 y10 w200", rule.hotkey)

    dlg.AddText("x10 y43", "名称:")
    ctlName := dlg.AddEdit("x70 y40 w320", rule.name)

    dlg.AddText("x10 y73", "匹配条件:")
    ctlMatch := dlg.AddEdit("x70 y70 w420", rule.match)

    dlg.AddText("x10 y103", "排除正则:")
    ctlExclude := dlg.AddEdit("x70 y100 w420", rule.exclude)

    ctlEnabled := dlg.AddCheckbox("x70 y130", "启用此规则")
    ctlEnabled.Value := rule.enabled

    dlg.AddText("x10 y155 w480", "热键格式: #=Win  !=Alt  ^=Ctrl  +=Shift  | 反引号用 vkC0  | 匹配条件: ahk_exe 进程名 / 标题关键词 / ahk_class 类名，可组合").SetFont("s9 cGray")

    result := false

    OK_Click(*) {
        rule.hotkey  := ctlHotkey.Value
        rule.name    := ctlName.Value
        rule.match   := ctlMatch.Value
        rule.exclude := ctlExclude.Value
        rule.enabled := ctlEnabled.Value
        result := true
        dlg.Destroy()
    }

    Cancel_Click(*) {
        dlg.Destroy()
    }

    dlg.AddButton("x320 y185 w80 h30 Default", "确定").OnEvent("Click", OK_Click)
    dlg.AddButton("x410 y185 w80 h30", "取消").OnEvent("Click", Cancel_Click)

    dlg.Show("w510 h225")
    return result
}

; ================================================================
;  窗口探测器
; ================================================================

ShowDetectorGui() {
    global detectorGui, lvDetector

    if (detectorGui != "") {
        detectorGui.Show()
        RefreshDetectorList()
        return
    }

    detectorGui := Gui(, "窗口探测器")
    detectorGui.SetFont("s10", "Microsoft YaHei UI")
    detectorGui.OnEvent("Close", (*) => detectorGui.Hide())

    lvDetector := detectorGui.AddListView("x10 y10 w720 h340", ["句柄", "标题", "类名", "进程名"])
    lvDetector.ModifyCol(1, 80)
    lvDetector.ModifyCol(2, 320)
    lvDetector.ModifyCol(3, 150)
    lvDetector.ModifyCol(4, 150)
    lvDetector.OnEvent("DoubleClick", (*) => CopySelectedMatch())

    detectorGui.AddButton("x10 y360 w100 h30", "刷新").OnEvent("Click", (*) => RefreshDetectorList())
    detectorGui.AddButton("x120 y360 w160 h30", "复制匹配条件(ahk_exe)").OnEvent("Click", (*) => CopySelectedMatch())
    detectorGui.AddButton("x290 y360 w160 h30", "复制标题匹配").OnEvent("Click", (*) => CopySelectedTitle())
    detectorGui.AddButton("x650 y360 w80 h30", "关闭").OnEvent("Click", (*) => detectorGui.Hide())

    detectorGui.Show("w740 h405")
    RefreshDetectorList()
}

RefreshDetectorList() {
    global lvDetector
    if (lvDetector = "")
        return
    lvDetector.Delete()

    wins := WinGetList()
    for hwnd in wins {
        if !WinExist("ahk_id " hwnd)
            continue
        title   := WinGetTitle("ahk_id " hwnd)
        class   := WinGetClass("ahk_id " hwnd)
        process := WinGetProcessName("ahk_id " hwnd)
        if (title != "" || class != "")
            lvDetector.Add(, hwnd, title, class, process)
    }
}

GetDetectorHwnd() {
    global lvDetector
    if (lvDetector = "")
        return ""
    sel := lvDetector.GetNext(0, "S")
    if (sel = 0)
        return ""
    return lvDetector.GetText(sel, 1)
}

CopySelectedMatch() {
    hwnd := GetDetectorHwnd()
    if (hwnd = "") {
        MsgBox("请先选择一个窗口", "提示", "T3")
        return
    }
    process := WinGetProcessName("ahk_id " hwnd)
    match := "ahk_exe " process
    A_Clipboard := match
    TrayTip("窗口探测器", "已复制: " match, , 1500)
}

CopySelectedTitle() {
    hwnd := GetDetectorHwnd()
    if (hwnd = "") {
        MsgBox("请先选择一个窗口", "提示", "T3")
        return
    }
    title := WinGetTitle("ahk_id " hwnd)
    A_Clipboard := title
    TrayTip("窗口探测器", "已复制标题: " title, , 1500)
}
