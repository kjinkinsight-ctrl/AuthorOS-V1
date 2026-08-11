/*
=========================================================
AUTHOROS
SETTINGS SERVICE
Milestone 14
=========================================================
*/

(function () {

    "use strict";

    class AuthorOSSettingsService {

        constructor(core) {
            this.core = core;
            this.settingsVersion = 4;

            this.shortcutDefinitions = [
                { action: "openSearch", label: "Open Universal Search", category: "Navigation", defaultBinding: "Ctrl+K" },
                { action: "openDashboard", label: "Open Dashboard", category: "Navigation", defaultBinding: "Ctrl+Shift+D" },
                { action: "openSettings", label: "Open Settings", category: "Navigation", defaultBinding: "Ctrl+Shift+S" },
                { action: "openBackupExport", label: "Open Backup & Export", category: "Navigation", defaultBinding: "Ctrl+Shift+B" }
            ];

            this.themeRegistry = [
                {
                    id: "obsidian",
                    name: "Obsidian",
                    description: "Sophisticated dark writing environment with warm literary accents.",
                    mode: "dark",
                    defaultAccent: "#c79a52"
                },
                {
                    id: "midnight",
                    name: "Midnight",
                    description: "Deep blue-black environment for focused late-night writing.",
                    mode: "dark",
                    defaultAccent: "#4f7ee8"
                },
                {
                    id: "forest",
                    name: "Forest",
                    description: "Deep green literary environment with natural calm contrast.",
                    mode: "dark",
                    defaultAccent: "#6fa87a"
                },
                {
                    id: "burgundy",
                    name: "Burgundy",
                    description: "Dramatic dark wine atmosphere with luxurious literary tones.",
                    mode: "dark",
                    defaultAccent: "#c9857f"
                },
                {
                    id: "plum",
                    name: "Plum",
                    description: "Deep violet creative environment with atmospheric contrast.",
                    mode: "dark",
                    defaultAccent: "#b896e8"
                },
                {
                    id: "ocean",
                    name: "Ocean",
                    description: "Deep blue and teal environment that feels modern and calm.",
                    mode: "dark",
                    defaultAccent: "#39a8a0"
                },
                {
                    id: "paper",
                    name: "Paper",
                    description: "Warm manuscript-like light environment built for long sessions.",
                    mode: "light",
                    defaultAccent: "#8e6532"
                },
                {
                    id: "slate",
                    name: "Slate",
                    description: "Clean light modern theme with cool professional balance.",
                    mode: "light",
                    defaultAccent: "#3f6fd8"
                }
            ];

            this.accentRegistry = [
                { id: "default", label: "Theme Default", color: "" },
                { id: "amber", label: "Amber", color: "#b67a2b" },
                { id: "teal", label: "Teal", color: "#1f8f86" },
                { id: "crimson", label: "Crimson", color: "#b44a55" },
                { id: "cobalt", label: "Cobalt", color: "#3f6fd8" },
                { id: "olive", label: "Olive", color: "#738638" },
                { id: "coral", label: "Coral", color: "#cf6f55" },
                { id: "slate", label: "Slate", color: "#5f7488" },
                { id: "custom", label: "Custom", color: "" }
            ];
        }


        getThemeRegistry() {
            return this.themeRegistry.map(item => ({ ...item }));
        }


        getAccentRegistry() {
            return this.accentRegistry.map(item => ({ ...item }));
        }


        getDefaultThemeId() {
            return "obsidian";
        }


        getThemeById(themeId) {
            const target = String(themeId || "").trim().toLowerCase();
            return this.themeRegistry.find(item => item.id === target) || null;
        }


        resolveLegacyThemeId(value) {
            const raw = String(value || "").trim().toLowerCase();

            if (raw === "light") {
                return "paper";
            }

            if (raw === "dark" || raw === "system") {
                return "obsidian";
            }

            return raw;
        }


        getThemeDefaultAccent(themeId) {
            return this.getThemeById(themeId)?.defaultAccent || this.getThemeById(this.getDefaultThemeId())?.defaultAccent || "#c79a52";
        }


        getDefaultSettings() {
            return {
                settingsVersion: this.settingsVersion,
                appearance: {
                    theme: this.getDefaultThemeId(),
                    accent: "default",
                    accentColor: "",
                    dashboardBackground: {
                        image: null,
                        position: "center",
                        size: "cover"
                    },
                    density: "comfortable",
                    sidebarCollapsed: false,
                    reducedEffects: false
                },
                editor: {
                    fontFamily: "merriweather",
                    fontSize: 18,
                    lineHeight: 1.65,
                    paragraphSpacing: "normal",
                    editorWidth: "normal",
                    spellcheck: true,
                    focusModeSticky: false,
                    showWordCount: true,
                    showWritingStats: true
                },
                application: {
                    startupView: "last-view",
                    openLastProject: true,
                    autosaveIntervalMs: 1200,
                    confirmBeforeExit: true,
                    defaultLandingView: "dashboard"
                },
                tutorial: {
                    enabled: true,
                    completed: false,
                    dismissed: false,
                    currentStep: "welcome",
                    completedAt: "",
                    lastPromptedAt: ""
                },
                notifications: {
                    enabled: true,
                    save: true,
                    backupExport: true,
                    system: true,
                    durationMs: 3000
                },
                accessibility: {
                    reducedMotion: false,
                    highContrast: false,
                    largeText: false,
                    enhancedFocus: true,
                    keyboardFirst: true
                },
                shortcuts: {
                    bindings: this.getDefaultShortcutBindings()
                },
                data: {
                    backupReminderDays: 7,
                    lastSettingsResetAt: ""
                },
                updatedAt: new Date().toISOString()
            };
        }


        getDefaultShortcutBindings() {
            const bindings = {};

            this.shortcutDefinitions.forEach(definition => {
                bindings[definition.action] = definition.defaultBinding;
            });

            return bindings;
        }


        getShortcutDefinitions() {
            return this.shortcutDefinitions.map(item => ({ ...item }));
        }


        loadSettings() {
            const raw = this.core.storage.loadSettings();
            const migrated = this.migrateSettings(raw);
            const normalized = this.normalizeSettings(migrated);

            this.core.storage.saveSettings(normalized);

            return normalized;
        }


        migrateSettings(settings) {
            const source = settings && typeof settings === "object" ? this.cloneData(settings) : {};
            const defaults = this.getDefaultSettings();
            const hadExistingSettings = source && Object.keys(source).length > 0;

            if (!source.settingsVersion) {
                source.settingsVersion = 1;
            }

            if (typeof source.theme === "string") {
                source.appearance = {
                    ...(source.appearance || {}),
                    theme: this.resolveLegacyThemeId(source.theme)
                };
            }

            if (source.appearance && typeof source.appearance === "object") {
                source.appearance.theme = this.resolveLegacyThemeId(source.appearance.theme);

                if (!source.appearance.accentColor && source.appearance.accentColour) {
                    source.appearance.accentColor = source.appearance.accentColour;
                }
            }

            if (source.manuscriptEditor && typeof source.manuscriptEditor === "object") {
                source.editor = {
                    ...(source.editor || {}),
                    fontSize: source.manuscriptEditor.fontSize,
                    lineHeight: source.manuscriptEditor.lineHeight,
                    editorWidth: source.manuscriptEditor.editorWidth,
                    spellcheck: source.manuscriptEditor.spellcheck
                };
            }

            if (!source.shortcuts || typeof source.shortcuts !== "object") {
                source.shortcuts = {
                    bindings: this.getDefaultShortcutBindings()
                };
            }

            if (!source.tutorial || typeof source.tutorial !== "object") {
                source.tutorial = {
                    ...defaults.tutorial,
                    completed: hadExistingSettings,
                    dismissed: false
                };
            }

            source.settingsVersion = Number(source.settingsVersion || 1);

            if (source.settingsVersion > this.settingsVersion) {
                return {
                    ...defaults,
                    updatedAt: new Date().toISOString()
                };
            }

            return source;
        }


        normalizeSettings(settings) {
            const defaults = this.getDefaultSettings();
            const source = settings && typeof settings === "object" ? settings : {};
            const themeIds = this.themeRegistry.map(item => item.id);
            const accentIds = this.accentRegistry.map(item => item.id);

            const normalized = this.cloneData(defaults);

            normalized.settingsVersion = this.settingsVersion;
            normalized.appearance.theme = this.pickEnum(
                this.resolveLegacyThemeId(source?.appearance?.theme),
                themeIds,
                defaults.appearance.theme
            );
            normalized.appearance.accent = this.pickEnum(
                source?.appearance?.accent,
                accentIds,
                defaults.appearance.accent
            );
            normalized.appearance.accentColor =
                this.normalizeHexColor(
                    source?.appearance?.accentColor || source?.appearance?.accentColour || ""
                ) || "";
            normalized.appearance.dashboardBackground =
                this.normalizeDashboardBackground(
                    source?.appearance?.dashboardBackground,
                    defaults.appearance.dashboardBackground
                );
            normalized.appearance.density = this.pickEnum(source?.appearance?.density, ["compact", "comfortable", "spacious"], defaults.appearance.density);
            normalized.appearance.sidebarCollapsed = this.pickBoolean(source?.appearance?.sidebarCollapsed, defaults.appearance.sidebarCollapsed);
            normalized.appearance.reducedEffects = this.pickBoolean(source?.appearance?.reducedEffects, defaults.appearance.reducedEffects);

            normalized.editor.fontFamily = this.pickEnum(
                source?.editor?.fontFamily,
                [
                    "merriweather",
                    "inter",
                    "jetbrains-mono",
                    "georgia",
                    "times-new-roman",
                    "garamond",
                    "palatino",
                    "arial",
                    "verdana",
                    "courier-new"
                ],
                defaults.editor.fontFamily
            );
            normalized.editor.fontSize = this.pickNumber(source?.editor?.fontSize, 14, 28, defaults.editor.fontSize, true);
            normalized.editor.lineHeight = this.pickNumber(source?.editor?.lineHeight, 1.3, 2, defaults.editor.lineHeight, false);
            normalized.editor.paragraphSpacing = this.pickEnum(source?.editor?.paragraphSpacing, ["tight", "normal", "relaxed"], defaults.editor.paragraphSpacing);
            normalized.editor.editorWidth = this.pickEnum(source?.editor?.editorWidth, ["narrow", "normal", "wide"], defaults.editor.editorWidth);
            normalized.editor.spellcheck = this.pickBoolean(source?.editor?.spellcheck, defaults.editor.spellcheck);
            normalized.editor.focusModeSticky = this.pickBoolean(source?.editor?.focusModeSticky, defaults.editor.focusModeSticky);
            normalized.editor.showWordCount = this.pickBoolean(source?.editor?.showWordCount, defaults.editor.showWordCount);
            normalized.editor.showWritingStats = this.pickBoolean(source?.editor?.showWritingStats, defaults.editor.showWritingStats);

            normalized.application.startupView = this.pickEnum(
                source?.application?.startupView,
                ["last-view", "dashboard", "projects", "manuscript", "search", "statistics", "backup-export", "settings"],
                defaults.application.startupView
            );
            normalized.application.openLastProject = this.pickBoolean(source?.application?.openLastProject, defaults.application.openLastProject);
            normalized.application.autosaveIntervalMs = this.pickNumber(source?.application?.autosaveIntervalMs, 500, 10000, defaults.application.autosaveIntervalMs, true);
            normalized.application.confirmBeforeExit = this.pickBoolean(source?.application?.confirmBeforeExit, defaults.application.confirmBeforeExit);
            normalized.application.defaultLandingView = this.pickEnum(
                source?.application?.defaultLandingView,
                ["dashboard", "projects", "manuscript", "search", "statistics", "backup-export", "settings"],
                defaults.application.defaultLandingView
            );

            normalized.tutorial.enabled = this.pickBoolean(source?.tutorial?.enabled, defaults.tutorial.enabled);
            normalized.tutorial.completed = this.pickBoolean(source?.tutorial?.completed, defaults.tutorial.completed);
            normalized.tutorial.dismissed = this.pickBoolean(source?.tutorial?.dismissed, defaults.tutorial.dismissed);
            normalized.tutorial.currentStep = this.pickString(source?.tutorial?.currentStep, defaults.tutorial.currentStep) || defaults.tutorial.currentStep;
            normalized.tutorial.completedAt = this.pickString(source?.tutorial?.completedAt, defaults.tutorial.completedAt);
            normalized.tutorial.lastPromptedAt = this.pickString(source?.tutorial?.lastPromptedAt, defaults.tutorial.lastPromptedAt);

            normalized.notifications.enabled = this.pickBoolean(source?.notifications?.enabled, defaults.notifications.enabled);
            normalized.notifications.save = this.pickBoolean(source?.notifications?.save, defaults.notifications.save);
            normalized.notifications.backupExport = this.pickBoolean(source?.notifications?.backupExport, defaults.notifications.backupExport);
            normalized.notifications.system = this.pickBoolean(source?.notifications?.system, defaults.notifications.system);
            normalized.notifications.durationMs = this.pickNumber(source?.notifications?.durationMs, 1200, 12000, defaults.notifications.durationMs, true);

            normalized.accessibility.reducedMotion = this.pickBoolean(source?.accessibility?.reducedMotion, defaults.accessibility.reducedMotion);
            normalized.accessibility.highContrast = this.pickBoolean(source?.accessibility?.highContrast, defaults.accessibility.highContrast);
            normalized.accessibility.largeText = this.pickBoolean(source?.accessibility?.largeText, defaults.accessibility.largeText);
            normalized.accessibility.enhancedFocus = this.pickBoolean(source?.accessibility?.enhancedFocus, defaults.accessibility.enhancedFocus);
            normalized.accessibility.keyboardFirst = this.pickBoolean(source?.accessibility?.keyboardFirst, defaults.accessibility.keyboardFirst);

            const defaultBindings = this.getDefaultShortcutBindings();
            const sourceBindings = source?.shortcuts?.bindings && typeof source.shortcuts.bindings === "object"
                ? source.shortcuts.bindings
                : {};

            normalized.shortcuts.bindings = {};

            Object.keys(defaultBindings).forEach(action => {
                normalized.shortcuts.bindings[action] = this.normalizeShortcutBinding(sourceBindings[action] || defaultBindings[action]);
            });

            const conflicts = this.findShortcutConflicts(normalized.shortcuts.bindings);

            if (conflicts.length > 0) {
                normalized.shortcuts.bindings = defaultBindings;
            }

            normalized.data.backupReminderDays = this.pickNumber(source?.data?.backupReminderDays, 1, 90, defaults.data.backupReminderDays, true);
            normalized.data.lastSettingsResetAt = this.pickString(source?.data?.lastSettingsResetAt, defaults.data.lastSettingsResetAt);

            normalized.updatedAt = new Date().toISOString();

            normalized.theme = normalized.appearance.theme;
            normalized.manuscriptEditor = {
                fontSize: normalized.editor.fontSize,
                lineHeight: normalized.editor.lineHeight,
                editorWidth: normalized.editor.editorWidth,
                spellcheck: normalized.editor.spellcheck
            };

            return normalized;
        }


        saveSettings(nextSettings) {
            const normalized = this.normalizeSettings(nextSettings);

            const persisted = this.core.storage.saveSettings(normalized);

            if (!persisted) {
                return {
                    ok: false,
                    error: "Settings could not be saved."
                };
            }

            this.core.state.set("settings", normalized);
            this.applySettings(normalized);

            this.core.events.emit("settings:changed", {
                settings: normalized
            });

            this.core.events.emit("storage:changed");

            return {
                ok: true,
                settings: normalized
            };
        }


        updateSection(sectionKey, sectionValue) {
            const current = this.core.state.get("settings") || this.loadSettings();
            const next = this.cloneData(current) || this.getDefaultSettings();
            next[sectionKey] = sectionValue;
            return this.saveSettings(next);
        }


        resetSection(sectionKey) {
            const defaults = this.getDefaultSettings();
            const current = this.core.state.get("settings") || this.loadSettings();
            const next = this.cloneData(current) || this.getDefaultSettings();

            if (!(sectionKey in defaults)) {
                return {
                    ok: false,
                    error: "Unknown settings section."
                };
            }

            next[sectionKey] = this.cloneData(defaults[sectionKey]);
            next.data = {
                ...(next.data || {}),
                lastSettingsResetAt: new Date().toISOString()
            };

            return this.saveSettings(next);
        }


        resetAll() {
            const defaults = this.getDefaultSettings();
            defaults.data.lastSettingsResetAt = new Date().toISOString();
            return this.saveSettings(defaults);
        }


        applySettings(settingsInput = null) {
            const settings = settingsInput || this.core.state.get("settings") || this.loadSettings();

            this.applyAppearance(settings);
            this.applyAccessibility(settings);
            this.applyRuntimePreferences(settings);
        }


        applyAppearance(settings) {
            const root = document.documentElement;
            const defaults = this.getDefaultSettings().appearance;
            const appearance = settings.appearance || defaults;
            const themeId = this.pickEnum(
                this.resolveLegacyThemeId(appearance.theme),
                this.themeRegistry.map(item => item.id),
                defaults.theme
            );
            const accentId = this.pickEnum(
                appearance.accent,
                this.accentRegistry.map(item => item.id),
                defaults.accent
            );
            const accentColor = this.normalizeHexColor(appearance.accentColor || "");

            root.setAttribute("data-theme", themeId);
            root.setAttribute("data-accent", accentId);
            root.setAttribute("data-density", appearance.density || defaults.density);

            const theme = this.getThemeById(themeId) || this.getThemeById(this.getDefaultThemeId());
            const resolvedAccent = this.resolveAccentColor(themeId, accentId, accentColor);
            const hoverAccent = this.shiftColor(resolvedAccent, theme?.mode === "dark" ? 0.14 : -0.12);
            const activeAccent = this.shiftColor(resolvedAccent, theme?.mode === "dark" ? 0.04 : -0.2);
            const accentSoft = this.toRGBA(resolvedAccent, theme?.mode === "dark" ? 0.26 : 0.18);
            const accentText = this.getReadableTextColor(resolvedAccent);

            root.style.setProperty("--color-accent", resolvedAccent);
            root.style.setProperty("--color-accent-hover", hoverAccent);
            root.style.setProperty("--color-accent-active", activeAccent);
            root.style.setProperty("--color-accent-soft", accentSoft);
            root.style.setProperty("--button-primary-background", resolvedAccent);
            root.style.setProperty("--button-primary-background-hover", hoverAccent);
            root.style.setProperty("--button-primary-background-active", activeAccent);
            root.style.setProperty("--button-primary-text", accentText);
            root.style.setProperty("--focus-ring-color", accentSoft);

            if (accentId === "custom") {
                root.style.setProperty("--authoros-accent-override", resolvedAccent);
            } else {
                root.style.removeProperty("--authoros-accent-override");
            }

            root.classList.toggle("reduced-effects", Boolean(appearance.reducedEffects));

            this.applyThemeMetaColor();

            const collapsed = Boolean(appearance.sidebarCollapsed);
            const sidebar = this.core.sidebar;

            if (sidebar) {
                if (collapsed) {
                    sidebar.collapse();
                } else {
                    sidebar.expand();
                }
            }
        }


        previewAppearance(appearancePatch = {}) {
            const settings = this.core.state.get("settings") || this.loadSettings();
            const preview = this.cloneData(settings) || this.getDefaultSettings();

            preview.appearance = {
                ...(preview.appearance || {}),
                ...(appearancePatch || {})
            };

            const normalized = this.normalizeSettings(preview);
            this.applyAppearance(normalized);

            return normalized.appearance;
        }


        applyAccessibility(settings) {
            const root = document.documentElement;
            const accessibility = settings.accessibility || this.getDefaultSettings().accessibility;

            root.classList.toggle("reduced-motion", Boolean(accessibility.reducedMotion));
            root.classList.toggle("high-contrast-ui", Boolean(accessibility.highContrast));
            root.classList.toggle("large-ui-text", Boolean(accessibility.largeText));
            root.classList.toggle("enhanced-focus", Boolean(accessibility.enhancedFocus));
        }


        applyRuntimePreferences(settings) {
            const appPrefs = settings.application || this.getDefaultSettings().application;
            const editorPrefs = settings.editor || this.getDefaultSettings().editor;

            if (this.core.autosave) {
                this.core.autosave.debounceMs = Number(appPrefs.autosaveIntervalMs || 1200);
            }

            const manuscriptModule = this.core.registry.get("manuscript");

            if (manuscriptModule) {
                manuscriptModule.autosaveDelay = Number(appPrefs.autosaveIntervalMs || 1200);
                manuscriptModule.editorSettings = {
                    ...(manuscriptModule.editorSettings || {}),
                    fontSize: editorPrefs.fontSize,
                    lineHeight: editorPrefs.lineHeight,
                    editorWidth: editorPrefs.editorWidth,
                    spellcheck: editorPrefs.spellcheck,
                    fontFamily: editorPrefs.fontFamily
                };
            }
        }


        getInitialRoute() {
            const settings = this.core.state.get("settings") || this.loadSettings();
            const startupView = settings?.application?.startupView || "last-view";

            if (startupView === "last-view") {
                return this.core.storage.loadCurrentView() || settings?.application?.defaultLandingView || "dashboard";
            }

            return startupView;
        }


        shouldOpenLastProject() {
            const settings = this.core.state.get("settings") || this.loadSettings();
            return Boolean(settings?.application?.openLastProject);
        }


        shouldConfirmBeforeExit() {
            const settings = this.core.state.get("settings") || this.loadSettings();
            return Boolean(settings?.application?.confirmBeforeExit);
        }


        getNotificationSettings() {
            const settings = this.core.state.get("settings") || this.loadSettings();
            return settings.notifications || this.getDefaultSettings().notifications;
        }


        shouldDisplayNotification(message, type = "info") {
            if (String(type).toLowerCase() === "error") {
                return true;
            }

            const prefs = this.getNotificationSettings();

            if (!prefs.enabled) {
                return false;
            }

            const text = String(message || "").toLowerCase();
            const appearsSave = text.includes("saved") || text.includes("autosave") || text.includes("save");
            const appearsBackup = text.includes("backup") || text.includes("export") || text.includes("import");

            if (appearsSave && !prefs.save) {
                return false;
            }

            if (appearsBackup && !prefs.backupExport) {
                return false;
            }

            if (!appearsSave && !appearsBackup && !prefs.system) {
                return false;
            }

            return true;
        }


        getNotificationDuration() {
            const prefs = this.getNotificationSettings();
            return Number.isFinite(Number(prefs.durationMs)) ? Number(prefs.durationMs) : 3000;
        }


        getShortcutBinding(action) {
            const settings = this.core.state.get("settings") || this.loadSettings();
            const binding = settings?.shortcuts?.bindings?.[action];
            const fallback = this.getDefaultShortcutBindings()[action] || "";
            return this.normalizeShortcutBinding(binding || fallback);
        }


        setShortcutBinding(action, binding) {
            const settings = this.core.state.get("settings") || this.loadSettings();
            const next = this.cloneData(settings) || this.getDefaultSettings();
            const defaults = this.getDefaultShortcutBindings();

            if (!(action in defaults)) {
                return {
                    ok: false,
                    error: "Unknown shortcut action."
                };
            }

            next.shortcuts = next.shortcuts && typeof next.shortcuts === "object"
                ? next.shortcuts
                : { bindings: defaults };

            next.shortcuts.bindings = next.shortcuts.bindings && typeof next.shortcuts.bindings === "object"
                ? next.shortcuts.bindings
                : { ...defaults };

            next.shortcuts.bindings[action] = this.normalizeShortcutBinding(binding);

            const conflicts = this.findShortcutConflicts(next.shortcuts.bindings);

            if (conflicts.length > 0) {
                return {
                    ok: false,
                    error: "Shortcut conflict detected.",
                    conflicts
                };
            }

            return this.saveSettings(next);
        }


        resetShortcut(action) {
            const defaults = this.getDefaultShortcutBindings();
            return this.setShortcutBinding(action, defaults[action]);
        }


        resetAllShortcuts() {
            const settings = this.core.state.get("settings") || this.loadSettings();
            const next = this.cloneData(settings) || this.getDefaultSettings();
            next.shortcuts = {
                bindings: this.getDefaultShortcutBindings()
            };
            return this.saveSettings(next);
        }


        findShortcutConflicts(bindings) {
            const map = new Map();
            const conflicts = [];
            const knownActions = Object.keys(this.getDefaultShortcutBindings());

            knownActions.forEach(action => {
                const binding = this.normalizeShortcutBinding(bindings[action]);

                if (!binding) {
                    return;
                }

                if (!map.has(binding)) {
                    map.set(binding, action);
                    return;
                }

                conflicts.push({
                    binding,
                    actions: [map.get(binding), action]
                });
            });

            return conflicts;
        }


        normalizeShortcutBinding(binding) {
            const raw = String(binding || "").trim();

            if (!raw) {
                return "";
            }

            const parts = raw
                .split("+")
                .map(part => part.trim())
                .filter(Boolean);

            const modifiers = [];
            let key = "";

            parts.forEach(part => {
                const lower = part.toLowerCase();

                if (lower === "ctrl" || lower === "control" || lower === "cmd" || lower === "meta") {
                    if (!modifiers.includes("Ctrl")) {
                        modifiers.push("Ctrl");
                    }
                    return;
                }

                if (lower === "shift") {
                    if (!modifiers.includes("Shift")) {
                        modifiers.push("Shift");
                    }
                    return;
                }

                if (lower === "alt") {
                    if (!modifiers.includes("Alt")) {
                        modifiers.push("Alt");
                    }
                    return;
                }

                key = part.length === 1
                    ? part.toUpperCase()
                    : part.charAt(0).toUpperCase() + part.slice(1).toLowerCase();
            });

            if (!key) {
                return "";
            }

            return [...modifiers, key].join("+");
        }


        isShortcutMatch(event, action) {

            const binding = this.getShortcutBinding(action);

            if (!binding) {
                return false;
            }

            const parts = binding.split("+").map(part => part.trim());
            const key = parts[parts.length - 1];
            const hasCtrl = parts.includes("Ctrl");
            const hasShift = parts.includes("Shift");
            const hasAlt = parts.includes("Alt");

            const eventKey = String(event.key || "").toLowerCase();
            const expectedKey = String(key || "").toLowerCase();

            if (eventKey !== expectedKey) {
                return false;
            }

            const ctrlMatch = hasCtrl ? (event.ctrlKey || event.metaKey) : (!event.ctrlKey && !event.metaKey);
            const shiftMatch = hasShift ? Boolean(event.shiftKey) : !event.shiftKey;
            const altMatch = hasAlt ? Boolean(event.altKey) : !event.altKey;

            return ctrlMatch && shiftMatch && altMatch;

        }


        getStorageInfo() {
            const settings = this.core.state.get("settings") || this.loadSettings();
            const prefix = `${this.core.storage.prefix}:`;

            let usedBytes = 0;
            let itemCount = 0;

            for (let index = 0; index < localStorage.length; index++) {
                const key = localStorage.key(index);

                if (!key || !key.startsWith(prefix)) {
                    continue;
                }

                const value = localStorage.getItem(key) || "";
                usedBytes += (key.length + value.length) * 2;
                itemCount += 1;
            }

            const lastBackup = this.core.storage.get("backupExportRecent", null);

            return {
                mechanism: "localStorage",
                version: this.core.getVersion(),
                settingsVersion: settings.settingsVersion,
                usedBytes,
                itemCount,
                lastBackup
            };
        }


        resolveAccentColor(themeId, accentId, accentColor) {
            const themeAccent = this.getThemeDefaultAccent(themeId);

            if (accentId === "default") {
                return themeAccent;
            }

            if (accentId === "custom") {
                return this.normalizeHexColor(accentColor) || themeAccent;
            }

            return this.getAccentRegistry().find(item => item.id === accentId)?.color || themeAccent;
        }


        normalizeHexColor(value) {
            const raw = String(value || "").trim();

            if (!raw) {
                return "";
            }

            const withHash = raw.startsWith("#") ? raw : `#${raw}`;
            const short = /^#([a-fA-F\d]{3})$/;
            const long = /^#([a-fA-F\d]{6})$/;

            if (short.test(withHash)) {
                const shortValue = withHash.slice(1);
                return `#${shortValue[0]}${shortValue[0]}${shortValue[1]}${shortValue[1]}${shortValue[2]}${shortValue[2]}`.toLowerCase();
            }

            if (long.test(withHash)) {
                return withHash.toLowerCase();
            }

            return "";
        }


        shiftColor(hexColor, amount) {
            const rgb = this.hexToRgb(hexColor);

            if (!rgb) {
                return hexColor;
            }

            const clamp = value => Math.max(0, Math.min(255, Math.round(value)));
            const factor = Number(amount);

            if (!Number.isFinite(factor)) {
                return hexColor;
            }

            const mix = factor >= 0 ? 255 : 0;
            const ratio = Math.min(Math.abs(factor), 1);

            return this.rgbToHex(
                clamp(rgb.r + (mix - rgb.r) * ratio),
                clamp(rgb.g + (mix - rgb.g) * ratio),
                clamp(rgb.b + (mix - rgb.b) * ratio)
            );
        }


        toRGBA(hexColor, alpha = 1) {
            const rgb = this.hexToRgb(hexColor);

            if (!rgb) {
                return `rgba(0, 0, 0, ${alpha})`;
            }

            const opacity = Math.max(0, Math.min(1, Number(alpha) || 1));
            return `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, ${opacity})`;
        }


        hexToRgb(hexColor) {
            const normalized = this.normalizeHexColor(hexColor);

            if (!normalized) {
                return null;
            }

            const value = normalized.slice(1);

            return {
                r: Number.parseInt(value.slice(0, 2), 16),
                g: Number.parseInt(value.slice(2, 4), 16),
                b: Number.parseInt(value.slice(4, 6), 16)
            };
        }


        rgbToHex(red, green, blue) {
            const toPart = value => String(Math.max(0, Math.min(255, Number(value) || 0)).toString(16)).padStart(2, "0");
            return `#${toPart(red)}${toPart(green)}${toPart(blue)}`;
        }


        getReadableTextColor(hexColor) {
            const rgb = this.hexToRgb(hexColor);

            if (!rgb) {
                return "#ffffff";
            }

            const luminance = ((0.299 * rgb.r) + (0.587 * rgb.g) + (0.114 * rgb.b)) / 255;
            return luminance > 0.62 ? "#121212" : "#ffffff";
        }


        applyThemeMetaColor() {
            const meta = document.querySelector('meta[name="theme-color"]');

            if (!meta) {
                return;
            }

            const color = getComputedStyle(document.documentElement)
                .getPropertyValue("--color-background")
                .trim();

            if (color) {
                meta.setAttribute("content", color);
            }
        }


        normalizeDashboardBackground(value, fallback) {

            const source = value && typeof value === "object"
                ? value
                : {};

            const normalizedFallback = fallback && typeof fallback === "object"
                ? fallback
                : {
                    image: null,
                    position: "center",
                    size: "cover"
                };

            const image = window.AuthorOSImageAssets
                ? window.AuthorOSImageAssets.normalizeStoredAsset(
                    source.image,
                    {
                        maxStoredBytes: 2 * 1024 * 1024
                    }
                )
                : null;

            return {
                image,
                position: this.pickEnum(
                    source.position,
                    ["center", "top", "bottom", "left", "right"],
                    normalizedFallback.position || "center"
                ),
                size: this.pickEnum(
                    source.size,
                    ["cover", "contain", "natural"],
                    normalizedFallback.size || "cover"
                )
            };

        }


        pickEnum(value, allowed, fallback) {
            const normalized = String(value || "").trim();
            return allowed.includes(normalized) ? normalized : fallback;
        }


        pickBoolean(value, fallback) {
            return typeof value === "boolean" ? value : fallback;
        }


        pickNumber(value, min, max, fallback, truncate = false) {
            const number = Number(value);

            if (!Number.isFinite(number)) {
                return fallback;
            }

            const clamped = Math.max(min, Math.min(max, number));

            return truncate ? Math.trunc(clamped) : clamped;
        }


        pickString(value, fallback) {
            return typeof value === "string" ? value : fallback;
        }


        cloneData(value) {
            try {
                return JSON.parse(JSON.stringify(value));
            } catch (error) {
                return null;
            }
        }

    }


    window.AuthorOSSettingsService = AuthorOSSettingsService;

})();
