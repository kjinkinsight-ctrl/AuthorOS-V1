/*
=========================================================
AUTHOROS
SETTINGS & PREFERENCES STUDIO
Milestone 14
=========================================================
*/

(function () {

    "use strict";

    window.AuthorOSSettings = {

        name: "settings",

        core: null,

        container: null,

        uiState: {
            category: "appearance",
            query: "",
            selectedProjectId: ""
        },

        categories: [
            { key: "appearance", label: "Appearance" },
            { key: "editor", label: "Writing & Editor" },
            { key: "application", label: "Application" },
            { key: "notifications", label: "Notifications" },
            { key: "accessibility", label: "Accessibility" },
            { key: "shortcuts", label: "Keyboard Shortcuts" },
            { key: "project", label: "Project Preferences" },
            { key: "data", label: "Data & Storage" },
            { key: "reset", label: "Reset & Safety" }
        ],

        initialize(core) {
            this.core = core;
        },


        render(container) {

            if (!container) {
                return;
            }

            this.container = container;
            this.ensureDefaults();

            const settings = this.getSettings();
            const storageInfo = this.getService().getStorageInfo();

            this.applyAppearancePreview(settings?.appearance || {});

            container.innerHTML = `
                <section class="settings-view library-view">
                    <header class="library-header">
                        <div class="library-heading">
                            <p class="eyebrow">SETTINGS & PREFERENCES</p>
                            <h1>Configure Author Studio</h1>
                            <p class="library-description">
                                Centralized global and project preferences with validation, migration safety, and reset controls.
                            </p>
                        </div>
                    </header>

                    <div class="library-controls settings-toolbar">
                        <div class="library-search">
                            <span class="library-search-icon" aria-hidden="true">⌕</span>
                            <input
                                id="settings-search-input"
                                class="library-search-input"
                                type="search"
                                placeholder="Search settings by name or behavior"
                                value="${this.escapeHTML(this.uiState.query)}"
                                aria-label="Search settings"
                            >
                            ${this.uiState.query
                                ? `<button type="button" class="library-search-clear" data-action="clear-settings-search" aria-label="Clear settings search">×</button>`
                                : ""
                            }
                        </div>

                        <div class="settings-toolbar-meta">
                            <span class="status-pill">Settings v${this.escapeHTML(String(settings.settingsVersion || 1))}</span>
                            <span class="settings-last-updated">Updated ${this.formatDate(settings.updatedAt)}</span>
                        </div>
                    </div>

                    <div class="settings-layout">
                        <nav class="settings-nav" aria-label="Settings categories">
                            ${this.renderCategoryNav()}
                        </nav>

                        <section class="settings-content" aria-live="polite">
                            ${this.renderCategoryPanel(settings, storageInfo)}
                        </section>
                    </div>
                </section>
            `;

            this.bindEvents(container);

        },


        renderCategoryNav() {
            return this.categories
                .map(category => {
                    const active = this.uiState.category === category.key;
                    return `
                        <button
                            type="button"
                            class="settings-nav-item ${active ? "active" : ""}"
                            data-action="open-settings-category"
                            data-category="${this.escapeHTML(category.key)}"
                        >
                            ${this.escapeHTML(category.label)}
                        </button>
                    `;
                })
                .join("");
        },


        renderCategoryPanel(settings, storageInfo) {

            const section = this.uiState.category;

            if (section === "appearance") {
                return this.renderAppearanceSection(settings);
            }

            if (section === "editor") {
                return this.renderEditorSection(settings);
            }

            if (section === "application") {
                return this.renderApplicationSection(settings);
            }

            if (section === "notifications") {
                return this.renderNotificationsSection(settings);
            }

            if (section === "accessibility") {
                return this.renderAccessibilitySection(settings);
            }

            if (section === "shortcuts") {
                return this.renderShortcutsSection(settings);
            }

            if (section === "project") {
                return this.renderProjectSection(settings);
            }

            if (section === "data") {
                return this.renderDataSection(settings, storageInfo);
            }

            if (section === "reset") {
                return this.renderResetSection(settings);
            }

            return "";

        },


        renderAppearanceSection(settings) {

            const value = settings.appearance;
            const service = this.getService();
            const themes = service.getThemeRegistry();
            const accentColor =
                value.accent === "custom"
                    ? service.normalizeHexColor(value.accentColor) || service.getThemeDefaultAccent(value.theme)
                    : service.resolveAccentColor(value.theme, value.accent, value.accentColor);

            const dashboardBackground =
                value.dashboardBackground && typeof value.dashboardBackground === "object"
                    ? value.dashboardBackground
                    : {
                        image: null,
                        position: "center",
                        size: "cover"
                    };

            const hasDashboardImage =
                Boolean(dashboardBackground.image?.dataUrl);

            return `
                <form class="settings-form" data-section="appearance" novalidate>
                    <h2>Appearance</h2>
                    <p class="settings-section-description">Theme, accent, visual density, sidebar behavior, and reduced visual effects.</p>

                    <label class="form-field" for="settings-theme">
                        <span>Theme</span>
                        <select id="settings-theme" name="theme">
                            ${themes
                                .map(theme => `
                                    <option value="${this.escapeHTML(theme.id)}" ${value.theme === theme.id ? "selected" : ""}>
                                        ${this.escapeHTML(theme.name)}
                                    </option>
                                `)
                                .join("")}
                        </select>
                    </label>

                    <div class="settings-theme-preview-grid" aria-label="Theme previews">
                        ${this.renderThemePreviewSwatches(value.theme)}
                    </div>

                    <label class="form-field" for="settings-accent">
                        <span>Accent</span>
                        <select id="settings-accent" name="accent">
                            ${this.getService()
                                .getAccentRegistry()
                                .map(accent => `
                                    <option value="${this.escapeHTML(accent.id)}" ${value.accent === accent.id ? "selected" : ""}>
                                        ${this.escapeHTML(accent.label)}
                                    </option>
                                `)
                                .join("")}
                        </select>
                    </label>

                    <div class="settings-accent-swatch-row" aria-label="Accent preview swatches">
                        ${this.renderAccentSwatches(value.accent)}
                    </div>

                    <label class="form-field" for="settings-accent-color">
                        <span>Custom accent colour</span>
                        <div class="settings-accent-color-row">
                            <input
                                id="settings-accent-color"
                                name="accentColor"
                                type="color"
                                value="${this.escapeHTML(accentColor)}"
                            >
                            <button
                                type="button"
                                class="button"
                                data-action="reset-accent-default"
                            >
                                Reset Accent
                            </button>
                        </div>
                    </label>

                    <label class="form-field" for="settings-density">
                        <span>Interface density</span>
                        <select id="settings-density" name="density">
                            <option value="compact" ${value.density === "compact" ? "selected" : ""}>Compact</option>
                            <option value="comfortable" ${value.density === "comfortable" ? "selected" : ""}>Comfortable</option>
                            <option value="spacious" ${value.density === "spacious" ? "selected" : ""}>Spacious</option>
                        </select>
                    </label>

                    <fieldset class="settings-subgroup">
                        <legend>Dashboard Background</legend>
                        <p class="settings-subgroup-description">
                            Choose a personal dashboard image while preserving readability.
                        </p>

                        ${this.renderDashboardBackgroundPreview(dashboardBackground)}

                        <div class="settings-dashboard-bg-actions">
                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="choose-dashboard-background"
                            >
                                ${hasDashboardImage ? "Change Image" : "Choose Image"}
                            </button>

                            <button
                                type="button"
                                class="button button-secondary"
                                data-action="remove-dashboard-background"
                                ${hasDashboardImage ? "" : "disabled"}
                            >
                                Remove Background
                            </button>
                        </div>

                        <input
                            id="settings-dashboard-background-input"
                            class="visually-hidden"
                            type="file"
                            accept="image/jpeg,image/jpg,image/png,image/webp"
                        >

                        <div class="settings-dashboard-bg-layout-controls">
                            <label class="form-field" for="settings-dashboard-background-position">
                                <span>Background position</span>
                                <select id="settings-dashboard-background-position" name="dashboardBackgroundPosition">
                                    <option value="center" ${dashboardBackground.position === "center" ? "selected" : ""}>Center</option>
                                    <option value="top" ${dashboardBackground.position === "top" ? "selected" : ""}>Top</option>
                                    <option value="bottom" ${dashboardBackground.position === "bottom" ? "selected" : ""}>Bottom</option>
                                    <option value="left" ${dashboardBackground.position === "left" ? "selected" : ""}>Left</option>
                                    <option value="right" ${dashboardBackground.position === "right" ? "selected" : ""}>Right</option>
                                </select>
                            </label>

                            <label class="form-field" for="settings-dashboard-background-size">
                                <span>Background size</span>
                                <select id="settings-dashboard-background-size" name="dashboardBackgroundSize">
                                    <option value="cover" ${dashboardBackground.size === "cover" ? "selected" : ""}>Cover</option>
                                    <option value="contain" ${dashboardBackground.size === "contain" ? "selected" : ""}>Contain</option>
                                    <option value="natural" ${dashboardBackground.size === "natural" ? "selected" : ""}>Natural</option>
                                </select>
                            </label>
                        </div>
                    </fieldset>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="sidebarCollapsed" ${value.sidebarCollapsed ? "checked" : ""}>
                        <span>Start with collapsed sidebar</span>
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="reducedEffects" ${value.reducedEffects ? "checked" : ""}>
                        <span>Reduce visual effects where supported</span>
                    </label>

                    ${this.renderFormFooter("appearance")}
                </form>
            `;

        },


        renderEditorSection(settings) {

            const value = settings.editor;

            return `
                <form class="settings-form" data-section="editor" novalidate>
                    <h2>Writing & Editor</h2>
                    <p class="settings-section-description">Default editor behavior without affecting existing manuscript content.</p>

                    <label class="form-field" for="settings-editor-font-family">
                        <span>Editor font family</span>
                        <select id="settings-editor-font-family" name="fontFamily">
                            <option value="merriweather" ${value.fontFamily === "merriweather" ? "selected" : ""}>Merriweather</option>
                            <option value="inter" ${value.fontFamily === "inter" ? "selected" : ""}>Inter</option>
                            <option value="jetbrains-mono" ${value.fontFamily === "jetbrains-mono" ? "selected" : ""}>JetBrains Mono</option>
                            <option value="georgia" ${value.fontFamily === "georgia" ? "selected" : ""}>Georgia</option>
                            <option value="times-new-roman" ${value.fontFamily === "times-new-roman" ? "selected" : ""}>Times New Roman</option>
                            <option value="garamond" ${value.fontFamily === "garamond" ? "selected" : ""}>Garamond</option>
                            <option value="palatino" ${value.fontFamily === "palatino" ? "selected" : ""}>Palatino</option>
                            <option value="arial" ${value.fontFamily === "arial" ? "selected" : ""}>Arial</option>
                            <option value="verdana" ${value.fontFamily === "verdana" ? "selected" : ""}>Verdana</option>
                            <option value="courier-new" ${value.fontFamily === "courier-new" ? "selected" : ""}>Courier New</option>
                        </select>
                    </label>

                    <label class="form-field" for="settings-editor-font-size">
                        <span>Font size</span>
                        <input id="settings-editor-font-size" name="fontSize" type="number" min="14" max="28" step="1" value="${this.escapeHTML(String(value.fontSize))}">
                    </label>

                    <label class="form-field" for="settings-editor-line-height">
                        <span>Line height</span>
                        <select id="settings-editor-line-height" name="lineHeight">
                            ${[1.4, 1.5, 1.6, 1.65, 1.7, 1.8].map(size => `
                                <option value="${size}" ${Number(value.lineHeight) === size ? "selected" : ""}>${size}</option>
                            `).join("")}
                        </select>
                    </label>

                    <label class="form-field" for="settings-editor-paragraph-spacing">
                        <span>Paragraph spacing</span>
                        <select id="settings-editor-paragraph-spacing" name="paragraphSpacing">
                            <option value="tight" ${value.paragraphSpacing === "tight" ? "selected" : ""}>Tight</option>
                            <option value="normal" ${value.paragraphSpacing === "normal" ? "selected" : ""}>Normal</option>
                            <option value="relaxed" ${value.paragraphSpacing === "relaxed" ? "selected" : ""}>Relaxed</option>
                        </select>
                    </label>

                    <label class="form-field" for="settings-editor-width">
                        <span>Editor width</span>
                        <select id="settings-editor-width" name="editorWidth">
                            <option value="narrow" ${value.editorWidth === "narrow" ? "selected" : ""}>Narrow</option>
                            <option value="normal" ${value.editorWidth === "normal" ? "selected" : ""}>Normal</option>
                            <option value="wide" ${value.editorWidth === "wide" ? "selected" : ""}>Wide</option>
                        </select>
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="spellcheck" ${value.spellcheck ? "checked" : ""}>
                        <span>Enable spellcheck</span>
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="focusModeSticky" ${value.focusModeSticky ? "checked" : ""}>
                        <span>Keep focus mode enabled between chapter switches</span>
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="showWordCount" ${value.showWordCount ? "checked" : ""}>
                        <span>Show editor word count</span>
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="showWritingStats" ${value.showWritingStats ? "checked" : ""}>
                        <span>Show writing statistics cards</span>
                    </label>

                    ${this.renderFormFooter("editor")}
                </form>
            `;

        },


        renderApplicationSection(settings) {

            const value = settings.application;
            const tutorial = settings.tutorial || {
                enabled: true,
                completed: false,
                dismissed: false,
                completedAt: ""
            };

            return `
                <form class="settings-form" data-section="application" novalidate>
                    <h2>Application Behavior</h2>
                    <p class="settings-section-description">Startup behavior, autosave timing, and navigation defaults.</p>

                    <label class="form-field" for="settings-startup-view">
                        <span>Startup view</span>
                        <select id="settings-startup-view" name="startupView">
                            <option value="last-view" ${value.startupView === "last-view" ? "selected" : ""}>Last visited view</option>
                            <option value="dashboard" ${value.startupView === "dashboard" ? "selected" : ""}>Dashboard</option>
                            <option value="projects" ${value.startupView === "projects" ? "selected" : ""}>Story Library</option>
                            <option value="manuscript" ${value.startupView === "manuscript" ? "selected" : ""}>Manuscript Studio</option>
                            <option value="search" ${value.startupView === "search" ? "selected" : ""}>Universal Search</option>
                            <option value="statistics" ${value.startupView === "statistics" ? "selected" : ""}>Statistics Studio</option>
                            <option value="backup-export" ${value.startupView === "backup-export" ? "selected" : ""}>Backup & Export Studio</option>
                            <option value="settings" ${value.startupView === "settings" ? "selected" : ""}>Settings</option>
                        </select>
                    </label>

                    <label class="form-field" for="settings-default-landing-view">
                        <span>Fallback landing view</span>
                        <select id="settings-default-landing-view" name="defaultLandingView">
                            <option value="dashboard" ${value.defaultLandingView === "dashboard" ? "selected" : ""}>Dashboard</option>
                            <option value="projects" ${value.defaultLandingView === "projects" ? "selected" : ""}>Story Library</option>
                            <option value="manuscript" ${value.defaultLandingView === "manuscript" ? "selected" : ""}>Manuscript Studio</option>
                            <option value="search" ${value.defaultLandingView === "search" ? "selected" : ""}>Universal Search</option>
                            <option value="statistics" ${value.defaultLandingView === "statistics" ? "selected" : ""}>Statistics Studio</option>
                            <option value="backup-export" ${value.defaultLandingView === "backup-export" ? "selected" : ""}>Backup & Export Studio</option>
                            <option value="settings" ${value.defaultLandingView === "settings" ? "selected" : ""}>Settings</option>
                        </select>
                    </label>

                    <label class="form-field" for="settings-autosave-interval">
                        <span>Autosave interval (ms)</span>
                        <input id="settings-autosave-interval" name="autosaveIntervalMs" type="number" min="500" max="10000" step="100" value="${this.escapeHTML(String(value.autosaveIntervalMs))}">
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="openLastProject" ${value.openLastProject ? "checked" : ""}>
                        <span>Reopen last active project</span>
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="confirmBeforeExit" ${value.confirmBeforeExit ? "checked" : ""}>
                        <span>Warn before leaving when unsaved writing changes exist</span>
                    </label>

                    <fieldset class="settings-subgroup">
                        <legend>Interactive Tutorial</legend>
                        <p class="settings-subgroup-description">Control the first-load guided introduction and restart it whenever you want a refresher.</p>

                        <label class="settings-checkbox-row">
                            <input type="checkbox" name="tutorialEnabled" ${tutorial.enabled !== false ? "checked" : ""}>
                            <span>Show tutorial for first-time users</span>
                        </label>

                        <p class="settings-reset-meta">
                            Tutorial status: ${tutorial.completed ? "Completed" : tutorial.dismissed ? "Skipped" : "Not finished"}
                            ${tutorial.completedAt ? ` | Completed ${this.formatDate(tutorial.completedAt)}` : ""}
                        </p>

                        <button type="button" class="button button-secondary" data-action="restart-app-tutorial">
                            Restart Tutorial
                        </button>

                        <button type="button" class="button button-secondary" data-action="resume-app-tutorial" ${tutorial.completed ? "disabled" : ""}>
                            Resume Tutorial
                        </button>

                        <button type="button" class="button button-secondary" data-action="view-app-tutorial-steps">
                            View Tutorial Steps
                        </button>
                    </fieldset>

                    ${this.renderFormFooter("application")}
                </form>
            `;

        },


        renderNotificationsSection(settings) {

            const value = settings.notifications;

            return `
                <form class="settings-form" data-section="notifications" novalidate>
                    <h2>Notifications</h2>
                    <p class="settings-section-description">Control routine notifications while preserving critical error alerts.</p>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="enabled" ${value.enabled ? "checked" : ""}>
                        <span>Enable routine notifications</span>
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="save" ${value.save ? "checked" : ""}>
                        <span>Show save/autosave notifications</span>
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="backupExport" ${value.backupExport ? "checked" : ""}>
                        <span>Show backup/export/import notifications</span>
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="system" ${value.system ? "checked" : ""}>
                        <span>Show general system notifications</span>
                    </label>

                    <label class="form-field" for="settings-notification-duration">
                        <span>Notification duration (ms)</span>
                        <input id="settings-notification-duration" name="durationMs" type="number" min="1200" max="12000" step="100" value="${this.escapeHTML(String(value.durationMs))}">
                    </label>

                    ${this.renderFormFooter("notifications")}
                </form>
            `;

        },


        renderAccessibilitySection(settings) {

            const value = settings.accessibility;

            return `
                <form class="settings-form" data-section="accessibility" novalidate>
                    <h2>Accessibility</h2>
                    <p class="settings-section-description">Prefer reduced motion, stronger contrast, and keyboard-first UX enhancements.</p>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="reducedMotion" ${value.reducedMotion ? "checked" : ""}>
                        <span>Reduce motion effects</span>
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="highContrast" ${value.highContrast ? "checked" : ""}>
                        <span>Increase UI contrast</span>
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="largeText" ${value.largeText ? "checked" : ""}>
                        <span>Use larger interface text</span>
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="enhancedFocus" ${value.enhancedFocus ? "checked" : ""}>
                        <span>Strengthen visible focus indicators</span>
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="keyboardFirst" ${value.keyboardFirst ? "checked" : ""}>
                        <span>Optimize for keyboard-first navigation</span>
                    </label>

                    ${this.renderFormFooter("accessibility")}
                </form>
            `;

        },


        renderShortcutsSection(settings) {

            const definitions = this.getService().getShortcutDefinitions();
            const bindings = settings.shortcuts?.bindings || {};

            const rows = definitions
                .map(definition => {
                    const value = bindings[definition.action] || definition.defaultBinding;

                    return `
                        <tr>
                            <td>${this.escapeHTML(definition.label)}</td>
                            <td>${this.escapeHTML(definition.category)}</td>
                            <td>
                                <input
                                    type="text"
                                    class="settings-shortcut-input"
                                    data-shortcut-action="${this.escapeHTML(definition.action)}"
                                    value="${this.escapeHTML(value)}"
                                    aria-label="Shortcut for ${this.escapeHTML(definition.label)}"
                                >
                            </td>
                            <td>
                                <button
                                    type="button"
                                    class="button button-secondary"
                                    data-action="reset-shortcut"
                                    data-shortcut-action="${this.escapeHTML(definition.action)}"
                                >
                                    Reset
                                </button>
                            </td>
                        </tr>
                    `;
                })
                .join("");

            return `
                <section class="settings-form" data-section="shortcuts">
                    <h2>Keyboard Shortcuts</h2>
                    <p class="settings-section-description">Customize supported navigation shortcuts. Browser and text-editing shortcuts remain protected.</p>

                    <div class="settings-table-wrap">
                        <table class="settings-table" aria-label="Shortcut configuration table">
                            <thead>
                                <tr>
                                    <th>Action</th>
                                    <th>Category</th>
                                    <th>Shortcut</th>
                                    <th>Reset</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${rows}
                            </tbody>
                        </table>
                    </div>

                    <div class="settings-form-footer">
                        <button type="button" class="button button-primary" data-action="save-shortcuts">Save Shortcuts</button>
                        <button type="button" class="button button-secondary" data-action="reset-all-shortcuts">Reset All Shortcuts</button>
                    </div>
                </section>
            `;

        },


        renderProjectSection(settings) {

            const projects = this.getProjects();
            const selectedProject = this.getSelectedProject();

            if (!projects.length) {
                return `
                    <section class="settings-form">
                        <h2>Project Preferences</h2>
                        <p class="settings-section-description">No active project is available. Create or open a project to manage project-level preferences.</p>
                    </section>
                `;
            }

            const preferences = this.getProjectPreferences(selectedProject);

            return `
                <form class="settings-form" data-section="project" novalidate>
                    <h2>Project Preferences</h2>
                    <p class="settings-section-description">Project-specific preferences remain isolated per project and never alter story content.</p>

                    <label class="form-field" for="settings-project-select">
                        <span>Project</span>
                        <select id="settings-project-select" name="projectSelect">
                            ${projects.map(project => `
                                <option value="${this.escapeHTML(project.id)}" ${selectedProject?.id === project.id ? "selected" : ""}>
                                    ${this.escapeHTML(this.getProjectTitle(project))}
                                </option>
                            `).join("")}
                        </select>
                    </label>

                    <label class="settings-checkbox-row">
                        <input type="checkbox" name="defaultFocusMode" ${preferences.defaultFocusMode ? "checked" : ""}>
                        <span>Default to focus mode for this project</span>
                    </label>

                    <label class="form-field" for="settings-project-editor-width">
                        <span>Project editor width override</span>
                        <select id="settings-project-editor-width" name="editorWidthOverride">
                            <option value="" ${!preferences.editorWidthOverride ? "selected" : ""}>Use global editor width</option>
                            <option value="narrow" ${preferences.editorWidthOverride === "narrow" ? "selected" : ""}>Narrow</option>
                            <option value="normal" ${preferences.editorWidthOverride === "normal" ? "selected" : ""}>Normal</option>
                            <option value="wide" ${preferences.editorWidthOverride === "wide" ? "selected" : ""}>Wide</option>
                        </select>
                    </label>

                    <label class="form-field" for="settings-project-sprint">
                        <span>Default sprint duration (minutes)</span>
                        <input id="settings-project-sprint" name="defaultSprintMinutes" type="number" min="5" max="240" step="1" value="${this.escapeHTML(String(preferences.defaultSprintMinutes))}">
                    </label>

                    ${this.renderFormFooter("project")}
                </form>
            `;

        },


        renderDataSection(settings, storageInfo) {

            const backup = storageInfo.lastBackup;

            return `
                <form class="settings-form" data-section="data" novalidate>
                    <h2>Data & Storage</h2>
                    <p class="settings-section-description">Read-only storage information and safe backup reminders.</p>

                    <dl class="settings-kv-grid">
                        <div><dt>Storage mechanism</dt><dd>${this.escapeHTML(storageInfo.mechanism)}</dd></div>
                        <div><dt>Author Studio version</dt><dd>${this.escapeHTML(storageInfo.version)}</dd></div>
                        <div><dt>Settings version</dt><dd>${this.escapeHTML(String(storageInfo.settingsVersion))}</dd></div>
                        <div><dt>Stored keys</dt><dd>${this.number(storageInfo.itemCount)}</dd></div>
                        <div><dt>Estimated storage</dt><dd>${this.formatBytes(storageInfo.usedBytes)}</dd></div>
                        <div><dt>Last backup/export</dt><dd>${backup ? this.escapeHTML(`${backup.fileName} (${this.formatDate(backup.exportedAt)})`) : "Unavailable"}</dd></div>
                    </dl>

                    <label class="form-field" for="settings-backup-reminder-days">
                        <span>Backup reminder cadence (days)</span>
                        <input id="settings-backup-reminder-days" name="backupReminderDays" type="number" min="1" max="90" step="1" value="${this.escapeHTML(String(settings.data.backupReminderDays))}">
                    </label>

                    <div class="settings-form-footer">
                        <button type="button" class="button button-primary" data-action="save-data-settings">Save Data Preferences</button>
                        <button type="button" class="button button-secondary" data-action="open-backup-export">Open Backup &amp; Export</button>
                    </div>
                </form>
            `;

        },


        renderResetSection(settings) {
            return `
                <section class="settings-form" data-section="reset">
                    <h2>Reset & Safety</h2>
                    <p class="settings-section-description">Reset preferences safely without deleting project content.</p>

                    <div class="settings-danger-zone">
                        <h3>Reset All Settings</h3>
                        <p>
                            This restores default preferences only. Projects, manuscript, story data, ideas, and backups are not deleted.
                        </p>
                        <button type="button" class="button button-danger" data-action="reset-all-settings">Reset All Settings</button>
                    </div>

                    <p class="settings-reset-meta">
                        Last settings reset: ${settings.data.lastSettingsResetAt ? this.formatDate(settings.data.lastSettingsResetAt) : "Never"}
                    </p>
                </section>
            `;
        },


        renderFormFooter(sectionKey) {
            return `
                <div class="settings-form-footer">
                    <button type="button" class="button button-primary" data-action="save-settings-section" data-section="${this.escapeHTML(sectionKey)}">Save ${this.escapeHTML(this.getSectionLabel(sectionKey))}</button>
                    <button type="button" class="button button-secondary" data-action="reset-settings-section" data-section="${this.escapeHTML(sectionKey)}">Reset This Section</button>
                </div>
            `;
        },


        bindEvents(container) {

            container.querySelectorAll('[data-action="open-settings-category"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    const next = String(button.dataset.category || "appearance");
                    this.uiState.category = next;
                    this.render(this.container);
                });
            });

            container.querySelector("#settings-search-input")?.addEventListener("input", event => {
                this.uiState.query = String(event.currentTarget.value || "").trim();
                this.applySearchFilter();
            });

            container.querySelector('[data-action="clear-settings-search"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.uiState.query = "";
                this.render(this.container);
            });

            container.querySelectorAll('[data-action="save-settings-section"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.handleSaveSection(String(button.dataset.section || ""));
                });
            });

            container.querySelectorAll('[data-action="reset-settings-section"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.handleResetSection(String(button.dataset.section || ""));
                });
            });

            container.querySelector('[data-action="save-shortcuts"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.handleSaveShortcuts();
            });

            container.querySelectorAll('[data-action="reset-shortcut"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.handleResetShortcut(String(button.dataset.shortcutAction || ""));
                });
            });

            container.querySelector('[data-action="reset-all-shortcuts"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.handleResetAllShortcuts();
            });

            container.querySelector('[data-action="save-data-settings"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.handleSaveDataSection();
            });

            container.querySelector('[data-action="open-backup-export"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.core.navigation.navigate("backup-export");
            });

            container.querySelector('[data-action="restart-app-tutorial"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.core.tutorialService?.restart?.();
            });

            container.querySelector('[data-action="resume-app-tutorial"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.core.tutorialService?.resume?.();
            });

            container.querySelector('[data-action="view-app-tutorial-steps"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.core.tutorialService?.openStepList?.();
            });

            container.querySelector("#settings-project-select")?.addEventListener("change", event => {
                this.uiState.selectedProjectId = String(event.currentTarget.value || "");
                this.render(this.container);
            });

            const accentSelect = container.querySelector("#settings-accent");
            const themeSelect = container.querySelector("#settings-theme");
            const accentColorInput = container.querySelector("#settings-accent-color");
            const dashboardInput = container.querySelector("#settings-dashboard-background-input");
            const dashboardPosition = container.querySelector("#settings-dashboard-background-position");
            const dashboardSize = container.querySelector("#settings-dashboard-background-size");

            themeSelect?.addEventListener("change", () => {
                this.syncThemePreview(themeSelect.value);
                this.persistAppearanceFromForm(false);
            });

            accentSelect?.addEventListener("change", () => {
                this.syncAccentSwatches(accentSelect.value);
                this.persistAppearanceFromForm(false);
            });

            accentColorInput?.addEventListener("input", () => {
                if (accentSelect && accentSelect.value !== "custom") {
                    accentSelect.value = "custom";
                    this.syncAccentSwatches("custom");
                }

                this.persistAppearanceFromForm(false);
            });

            dashboardPosition?.addEventListener("change", () => {
                this.persistAppearanceFromForm(false);
            });

            dashboardSize?.addEventListener("change", () => {
                this.persistAppearanceFromForm(false);
            });

            container.querySelectorAll("[data-accent-swatch]").forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();

                    const accent = String(button.dataset.accentSwatch || "default");

                    if (accentSelect) {
                        accentSelect.value = accent;
                        accentSelect.dispatchEvent(new Event("change", { bubbles: true }));
                    }
                });
            });

            container.querySelectorAll("[data-theme-preview]").forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();

                    const nextTheme = String(button.dataset.themePreview || "");

                    if (!nextTheme || !themeSelect) {
                        return;
                    }

                    themeSelect.value = nextTheme;
                    themeSelect.dispatchEvent(new Event("change", { bubbles: true }));
                });
            });

            container.querySelector('[data-action="reset-accent-default"]')?.addEventListener("click", event => {
                event.preventDefault();

                const form = this.getSectionForm("appearance");

                if (!form) {
                    return;
                }

                const fallbackTheme = String(form.theme?.value || this.getSettings().appearance.theme || "obsidian");
                const fallbackAccent = this.getService().getThemeDefaultAccent(fallbackTheme);

                if (accentSelect) {
                    accentSelect.value = "default";
                    this.syncAccentSwatches("default");
                }

                if (accentColorInput) {
                    accentColorInput.value = fallbackAccent;
                }

                this.persistAppearanceFromForm(false);
                this.core.notify("Accent reset to theme default.", "success");
            });

            container.querySelector('[data-action="choose-dashboard-background"]')?.addEventListener("click", async event => {
                event.preventDefault();

                if (window.AuthorOSDesktop?.isTauri?.()) {

                    const selected = await window.AuthorOSDesktop.openFile({
                        filters: [
                            {
                                name: "Images",
                                extensions: ["jpg", "jpeg", "png", "webp"]
                            }
                        ]
                    });

                    if (selected.canceled || !selected.ok) {

                        if (!selected.canceled && selected.error) {
                            this.core.notify(selected.error, "error");
                        }

                        return;

                    }

                    const file = selected.file || null;

                    if (!file || !window.AuthorOSImageAssets) {
                        return;
                    }

                    const processed = await window.AuthorOSImageAssets.processFile(
                        file,
                        {
                            maxFileBytes: 6 * 1024 * 1024,
                            maxWidth: 1920,
                            maxHeight: 1080,
                            outputType: "image/webp",
                            quality: 0.82
                        }
                    );

                    if (!processed.ok) {
                        this.core.notify(
                            processed.error || "Unable to use this image. Please choose a JPG, PNG, or WEBP image within the supported file size.",
                            "error"
                        );
                        return;
                    }

                    const form = this.getSectionForm("appearance");
                    const next = this.getAppearanceFromForm(form, this.getSettings().appearance);

                    next.dashboardBackground = {
                        ...(next.dashboardBackground || {}),
                        image: processed.asset,
                        position: String(dashboardPosition?.value || next.dashboardBackground?.position || "center"),
                        size: String(dashboardSize?.value || next.dashboardBackground?.size || "cover")
                    };

                    const result = this.getService().updateSection("appearance", next);

                    if (!result.ok) {
                        this.core.notify(result.error || "Unable to update dashboard background.", "error");
                        return;
                    }

                    this.core.notify("Dashboard background updated.", "success");
                    this.render(this.container);
                    return;

                }

                dashboardInput?.click();
            });

            dashboardInput?.addEventListener("change", async event => {
                const file = event?.currentTarget?.files?.[0] || null;

                if (!file || !window.AuthorOSImageAssets) {
                    return;
                }

                const processed = await window.AuthorOSImageAssets.processFile(
                    file,
                    {
                        maxFileBytes: 6 * 1024 * 1024,
                        maxWidth: 1920,
                        maxHeight: 1080,
                        outputType: "image/webp",
                        quality: 0.82
                    }
                );

                dashboardInput.value = "";

                if (!processed.ok) {
                    this.core.notify(
                        processed.error || "Unable to use this image. Please choose a JPG, PNG, or WEBP image within the supported file size.",
                        "error"
                    );
                    return;
                }

                const form = this.getSectionForm("appearance");
                const next = this.getAppearanceFromForm(form, this.getSettings().appearance);

                next.dashboardBackground = {
                    ...(next.dashboardBackground || {}),
                    image: processed.asset,
                    position: String(dashboardPosition?.value || next.dashboardBackground?.position || "center"),
                    size: String(dashboardSize?.value || next.dashboardBackground?.size || "cover")
                };

                const result = this.getService().updateSection("appearance", next);

                if (!result.ok) {
                    this.core.notify(result.error || "Dashboard background could not be saved.", "error");
                    return;
                }

                this.core.notify("Dashboard background updated.", "success");
                this.render(this.container);
            });

            container.querySelector('[data-action="remove-dashboard-background"]')?.addEventListener("click", event => {
                event.preventDefault();

                const form = this.getSectionForm("appearance");
                const next = this.getAppearanceFromForm(form, this.getSettings().appearance);

                next.dashboardBackground = {
                    ...(next.dashboardBackground || {}),
                    image: null,
                    position: String(dashboardPosition?.value || "center"),
                    size: String(dashboardSize?.value || "cover")
                };

                const result = this.getService().updateSection("appearance", next);

                if (!result.ok) {
                    this.core.notify(result.error || "Dashboard background could not be removed.", "error");
                    return;
                }

                this.core.notify("Dashboard background removed.", "success");
                this.render(this.container);
            });

            container.querySelector('[data-action="reset-all-settings"]')?.addEventListener("click", event => {
                event.preventDefault();
                this.handleResetAllSettings();
            });

            this.applySearchFilter();

        },


        applySearchFilter() {

            const query = this.uiState.query.toLowerCase();

            const content = this.container?.querySelector(".settings-content");

            if (!content) {
                return;
            }

            if (!query) {
                content.classList.remove("settings-search-empty");
                return;
            }

            const text = String(content.textContent || "").toLowerCase();

            if (text.includes(query)) {
                content.classList.remove("settings-search-empty");
                return;
            }

            content.classList.add("settings-search-empty");
            content.innerHTML = `
                <section class="library-empty-state settings-empty-search">
                    <div class="empty-state-icon">⌕</div>
                    <h2>No settings match</h2>
                    <p>Try a different setting keyword.</p>
                </section>
            `;

        },


        handleSaveSection(sectionKey) {

            if (!sectionKey) {
                return;
            }

            const current = this.getSettings();

            if (sectionKey === "appearance") {

                const form = this.getSectionForm("appearance");

                const next = this.getAppearanceFromForm(
                    form,
                    current.appearance
                );

                this.saveSection("appearance", next, "Appearance settings saved.");
                return;

            }

            if (sectionKey === "editor") {

                const form = this.getSectionForm("editor");

                const next = {
                    fontFamily: String(form?.fontFamily?.value || current.editor.fontFamily),
                    fontSize: Number(form?.fontSize?.value || current.editor.fontSize),
                    lineHeight: Number(form?.lineHeight?.value || current.editor.lineHeight),
                    paragraphSpacing: String(form?.paragraphSpacing?.value || current.editor.paragraphSpacing),
                    editorWidth: String(form?.editorWidth?.value || current.editor.editorWidth),
                    spellcheck: Boolean(form?.spellcheck?.checked),
                    focusModeSticky: Boolean(form?.focusModeSticky?.checked),
                    showWordCount: Boolean(form?.showWordCount?.checked),
                    showWritingStats: Boolean(form?.showWritingStats?.checked)
                };

                this.saveSection("editor", next, "Editor settings saved.");
                return;

            }

            if (sectionKey === "application") {

                const form = this.getSectionForm("application");

                const next = {
                    startupView: String(form?.startupView?.value || current.application.startupView),
                    defaultLandingView: String(form?.defaultLandingView?.value || current.application.defaultLandingView),
                    autosaveIntervalMs: Number(form?.autosaveIntervalMs?.value || current.application.autosaveIntervalMs),
                    openLastProject: Boolean(form?.openLastProject?.checked),
                    confirmBeforeExit: Boolean(form?.confirmBeforeExit?.checked)
                };

                const result = this.getService().saveSettings({
                    ...current,
                    application: next,
                    tutorial: {
                        ...(current.tutorial || {}),
                        enabled: Boolean(form?.tutorialEnabled?.checked)
                    }
                });

                if (!result.ok) {
                    this.core.notify(result.error || "Settings save failed.", "error");
                    return;
                }

                this.core.notify("Application settings saved.", "success");
                this.render(this.container);
                return;

            }

            if (sectionKey === "notifications") {

                const form = this.getSectionForm("notifications");

                const next = {
                    enabled: Boolean(form?.enabled?.checked),
                    save: Boolean(form?.save?.checked),
                    backupExport: Boolean(form?.backupExport?.checked),
                    system: Boolean(form?.system?.checked),
                    durationMs: Number(form?.durationMs?.value || current.notifications.durationMs)
                };

                this.saveSection("notifications", next, "Notification settings saved.");
                return;

            }

            if (sectionKey === "accessibility") {

                const form = this.getSectionForm("accessibility");

                const next = {
                    reducedMotion: Boolean(form?.reducedMotion?.checked),
                    highContrast: Boolean(form?.highContrast?.checked),
                    largeText: Boolean(form?.largeText?.checked),
                    enhancedFocus: Boolean(form?.enhancedFocus?.checked),
                    keyboardFirst: Boolean(form?.keyboardFirst?.checked)
                };

                this.saveSection("accessibility", next, "Accessibility settings saved.");
                return;

            }

            if (sectionKey === "project") {
                this.handleSaveProjectSection();
            }

        },


        handleSaveProjectSection() {

            const selectedProject = this.getSelectedProject();

            if (!selectedProject) {
                this.core.notify("Select a project to save project preferences.", "error");
                return;
            }

            const form = this.getSectionForm("project");
            const projects = this.core.state.get("projects");

            if (!Array.isArray(projects)) {
                this.core.notify("Project preference save failed.", "error");
                return;
            }

            const index = projects.findIndex(project => project.id === selectedProject.id);

            if (index === -1) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const nextProjects = this.cloneData(projects);
            const now = new Date().toISOString();

            nextProjects[index].preferences = nextProjects[index].preferences && typeof nextProjects[index].preferences === "object"
                ? nextProjects[index].preferences
                : {};

            nextProjects[index].preferences.editor = {
                defaultFocusMode: Boolean(form?.defaultFocusMode?.checked),
                editorWidthOverride: ["", "narrow", "normal", "wide"].includes(String(form?.editorWidthOverride?.value || ""))
                    ? String(form?.editorWidthOverride?.value || "")
                    : "",
                defaultSprintMinutes: Math.max(5, Math.min(240, Math.trunc(Number(form?.defaultSprintMinutes?.value || 15) || 15)))
            };

            nextProjects[index].updatedAt = now;
            nextProjects[index].lastModified = now;

            const projectsModule = this.core.registry.get("projects");
            const saved = projectsModule && typeof projectsModule.saveProjects === "function"
                ? projectsModule.saveProjects(nextProjects, { source: "settings-project-preferences" })
                : this.persistProjectsFallback(nextProjects);

            if (!saved) {
                this.core.notify("Project preferences could not be saved.", "error");
                return;
            }

            this.core.notify("Project preferences saved.", "success");
            this.render(this.container);

        },


        persistProjectsFallback(nextProjects) {

            const saved = this.core.storage.saveProjects(nextProjects);

            if (!saved) {
                return false;
            }

            this.core.state.set("projects", nextProjects);

            const currentProject = this.core.state.get("currentProject");

            if (currentProject?.id) {
                const synced = nextProjects.find(project => project.id === currentProject.id) || null;
                this.core.state.set("currentProject", synced);
            }

            this.core.events.emit("storage:changed");
            return true;

        },


        handleSaveDataSection() {

            const settings = this.getSettings();
            const form = this.getSectionForm("data");

            const nextData = {
                ...(settings.data || {}),
                backupReminderDays: Number(form?.backupReminderDays?.value || settings.data.backupReminderDays)
            };

            this.saveSection("data", nextData, "Data preferences saved.");

        },


        saveSection(sectionKey, value, successMessage) {

            const result = this.getService().updateSection(sectionKey, value);

            if (!result.ok) {
                this.core.notify(result.error || "Settings save failed.", "error");
                return;
            }

            this.core.notify(successMessage, "success");
            this.render(this.container);

        },


        handleResetSection(sectionKey) {

            const label = this.getSectionLabel(sectionKey);

            this.core.modal.open({
                title: `Reset ${label}`,
                content: `<p>Reset ${this.escapeHTML(label)} settings to defaults?</p><p>Project content will not be changed.</p>`,
                confirmText: "Reset Section",
                onConfirm: () => {
                    const result = this.getService().resetSection(sectionKey);

                    if (!result.ok) {
                        this.core.notify(result.error || "Section reset failed.", "error");
                        return;
                    }

                    this.core.notify(`${label} settings reset.`, "success");
                    this.render(this.container);
                }
            });

        },


        handleSaveShortcuts() {

            const settings = this.getSettings();
            const nextBindings = this.cloneData(settings.shortcuts?.bindings || {});

            this.getService().getShortcutDefinitions().forEach(definition => {
                const input = this.container?.querySelector(`[data-shortcut-action="${definition.action}"]`);
                if (!input) {
                    return;
                }
                nextBindings[definition.action] = this.getService().normalizeShortcutBinding(String(input.value || ""));
            });

            const conflicts = this.getService().findShortcutConflicts(nextBindings);

            if (conflicts.length > 0) {
                this.core.notify("Shortcut conflict detected. Resolve duplicates before saving.", "error");
                return;
            }

            const result = this.getService().updateSection("shortcuts", {
                bindings: nextBindings
            });

            if (!result.ok) {
                this.core.notify(result.error || "Shortcut save failed.", "error");
                return;
            }

            this.core.notify("Shortcuts saved.", "success");
            this.render(this.container);

        },


        handleResetShortcut(action) {

            const result = this.getService().resetShortcut(action);

            if (!result.ok) {
                this.core.notify(result.error || "Shortcut reset failed.", "error");
                return;
            }

            this.core.notify("Shortcut reset.", "success");
            this.render(this.container);

        },


        handleResetAllShortcuts() {

            this.core.modal.open({
                title: "Reset All Shortcuts",
                content: "<p>Reset all configurable shortcuts to defaults?</p>",
                confirmText: "Reset Shortcuts",
                onConfirm: () => {
                    const result = this.getService().resetAllShortcuts();

                    if (!result.ok) {
                        this.core.notify(result.error || "Shortcut reset failed.", "error");
                        return;
                    }

                    this.core.notify("All shortcuts reset.", "success");
                    this.render(this.container);
                }
            });

        },


        handleResetAllSettings() {

            this.core.modal.open({
                title: "Reset All Settings",
                content: "<p>Reset all settings to defaults?</p><p>This does not delete projects or writing content.</p>",
                confirmText: "Reset All",
                onConfirm: () => {
                    const result = this.getService().resetAll();

                    if (!result.ok) {
                        this.core.notify(result.error || "Reset all settings failed.", "error");
                        return;
                    }

                    this.core.notify("All settings reset to defaults.", "success");
                    this.render(this.container);
                }
            });

        },


        getSectionForm(sectionKey) {
            return this.container?.querySelector(`.settings-form[data-section="${sectionKey}"]`) || null;
        },


        getSettings() {
            return this.core.state.get("settings") || this.getService().loadSettings();
        },


        getProjects() {
            const projects = this.core.state.get("projects");
            return Array.isArray(projects)
                ? projects.filter(project => String(project?.status || "") !== "Archived")
                : [];
        },


        getSelectedProject() {
            const projects = this.getProjects();
            return projects.find(project => project.id === this.uiState.selectedProjectId) || projects[0] || null;
        },


        getProjectPreferences(project) {

            const source = project?.preferences?.editor && typeof project.preferences.editor === "object"
                ? project.preferences.editor
                : {};

            return {
                defaultFocusMode: Boolean(source.defaultFocusMode),
                editorWidthOverride: ["", "narrow", "normal", "wide"].includes(String(source.editorWidthOverride || ""))
                    ? String(source.editorWidthOverride || "")
                    : "",
                defaultSprintMinutes: Math.max(5, Math.min(240, Math.trunc(Number(source.defaultSprintMinutes || 15) || 15)))
            };

        },


        ensureDefaults() {

            if (!this.uiState.category) {
                this.uiState.category = "appearance";
            }

            const projects = this.getProjects();

            if (!projects.length) {
                this.uiState.selectedProjectId = "";
                return;
            }

            if (!projects.some(project => project.id === this.uiState.selectedProjectId)) {
                const currentProject = this.core.state.get("currentProject");
                this.uiState.selectedProjectId = currentProject?.id && projects.some(project => project.id === currentProject.id)
                    ? currentProject.id
                    : projects[0].id;
            }

        },


        getSectionLabel(sectionKey) {
            return this.categories.find(category => category.key === sectionKey)?.label || "Section";
        },


        renderAccentSwatches(activeAccent) {

            const accents = this.getService().getAccentRegistry();

            return accents
                .map(accent => {
                    const active = String(activeAccent || "default") === accent.id;

                    return `
                        <button
                            type="button"
                            class="settings-accent-swatch ${active ? "active" : ""}"
                            data-accent-swatch="${this.escapeHTML(accent.id)}"
                            aria-label="${this.escapeHTML(accent.label)} accent"
                            title="${this.escapeHTML(accent.label)}"
                        >
                            <span class="settings-accent-dot" data-accent-color="${this.escapeHTML(accent.id)}" aria-hidden="true"></span>
                        </button>
                    `;
                })
                .join("");

        },


        syncAccentSwatches(activeAccent) {

            this.container?.querySelectorAll("[data-accent-swatch]").forEach(button => {
                const isActive = String(button.dataset.accentSwatch || "") === String(activeAccent || "default");
                button.classList.toggle("active", isActive);
            });

        },


        syncThemePreview(activeTheme) {

            this.container?.querySelectorAll("[data-theme-preview]").forEach(button => {
                const active = String(button.dataset.themePreview || "") === String(activeTheme || "");
                button.classList.toggle("active", active);
            });

        },


        getAppearanceFromForm(form, fallbackAppearance = null) {

            const current = fallbackAppearance || this.getSettings().appearance || {};

            const dashboardCurrent =
                current.dashboardBackground && typeof current.dashboardBackground === "object"
                    ? current.dashboardBackground
                    : {
                        image: null,
                        position: "center",
                        size: "cover"
                    };

            return {
                theme: String(form?.theme?.value || current.theme || "obsidian"),
                accent: String(form?.accent?.value || current.accent || "default"),
                accentColor: String(form?.accentColor?.value || current.accentColor || ""),
                dashboardBackground: {
                    image: dashboardCurrent.image || null,
                    position: String(form?.dashboardBackgroundPosition?.value || dashboardCurrent.position || "center"),
                    size: String(form?.dashboardBackgroundSize?.value || dashboardCurrent.size || "cover")
                },
                density: String(form?.density?.value || current.density || "comfortable"),
                sidebarCollapsed: Boolean(form?.sidebarCollapsed?.checked),
                reducedEffects: Boolean(form?.reducedEffects?.checked)
            };

        },


        persistAppearanceFromForm(notify = false) {

            const form = this.getSectionForm("appearance");

            if (!form) {
                return;
            }

            const nextAppearance = this.getAppearanceFromForm(
                form,
                this.getSettings().appearance
            );

            const result = this.getService().updateSection(
                "appearance",
                nextAppearance
            );

            if (!result.ok) {
                this.core.notify(result.error || "Appearance update failed.", "error");
                return;
            }

            this.syncAccentSwatches(nextAppearance.accent);
            this.syncThemePreview(nextAppearance.theme);

            if (notify) {
                this.core.notify("Appearance settings saved.", "success");
            }

        },


        renderThemePreviewSwatches(activeTheme) {

            return this.getService()
                .getThemeRegistry()
                .map(theme => {
                    const selected = theme.id === activeTheme;

                    return `
                        <button
                            type="button"
                            class="settings-theme-preview ${selected ? "active" : ""}"
                            data-theme-preview="${this.escapeHTML(theme.id)}"
                            aria-label="${this.escapeHTML(theme.name)} theme"
                            title="${this.escapeHTML(theme.description)}"
                        >
                            <span class="settings-theme-preview-bar" style="${this.getThemePreviewStyle(theme.id)}"></span>
                            <span class="settings-theme-preview-name">${this.escapeHTML(theme.name)}</span>
                        </button>
                    `;
                })
                .join("");

        },


        getThemePreviewStyle(themeId) {

            const map = {
                obsidian: "--preview-bg:#11110f;--preview-surface:#1c1c18;--preview-text:#f3efe7;--preview-accent:#c79a52;--preview-border:#373229;",
                midnight: "--preview-bg:#090f1b;--preview-surface:#121a2b;--preview-text:#e9f0ff;--preview-accent:#4f7ee8;--preview-border:#26324d;",
                forest: "--preview-bg:#0e1713;--preview-surface:#17231d;--preview-text:#edf4ee;--preview-accent:#6fa87a;--preview-border:#2a3b33;",
                burgundy: "--preview-bg:#1c1114;--preview-surface:#28171d;--preview-text:#f3e8e4;--preview-accent:#c9857f;--preview-border:#4a2a33;",
                plum: "--preview-bg:#181220;--preview-surface:#251b30;--preview-text:#f1eafd;--preview-accent:#b896e8;--preview-border:#43325b;",
                ocean: "--preview-bg:#0d1622;--preview-surface:#172636;--preview-text:#e8f1fb;--preview-accent:#39a8a0;--preview-border:#2b4255;",
                paper: "--preview-bg:#f3efe4;--preview-surface:#fffaf0;--preview-text:#2a2722;--preview-accent:#8e6532;--preview-border:#d7cec0;",
                slate: "--preview-bg:#eef1f5;--preview-surface:#f8fafc;--preview-text:#202a34;--preview-accent:#3f6fd8;--preview-border:#d6dce5;"
            };

            return map[themeId] || map.obsidian;

        },


        applyAppearancePreview(appearance) {

            this.getService().previewAppearance(appearance || {});

        },


        renderDashboardBackgroundPreview(dashboardBackground) {

            const imageData =
                dashboardBackground?.image?.dataUrl || "";

            const position =
                String(dashboardBackground?.position || "center");

            const size =
                String(dashboardBackground?.size || "cover");

            if (!imageData) {
                return `
                    <div class="settings-dashboard-bg-preview settings-dashboard-bg-preview-empty" aria-label="Dashboard background preview">
                        <span>No custom background selected.</span>
                    </div>
                `;
            }

            const style = `background-image:url('${this.escapeHTML(imageData)}');background-position:${this.escapeHTML(position)};background-size:${size === "natural" ? "auto" : this.escapeHTML(size)};`;

            return `
                <div class="settings-dashboard-bg-preview" aria-label="Dashboard background preview" style="${style}">
                    <span>Preview</span>
                </div>
            `;

        },


        getProjectTitle(project) {
            return String(project?.name || project?.title || "Untitled Project").trim() || "Untitled Project";
        },


        getService() {
            return this.core.settingsService;
        },


        formatDate(value) {
            const date = new Date(value || "");
            return Number.isNaN(date.getTime())
                ? "Unavailable"
                : date.toLocaleString();
        },


        formatBytes(bytes) {
            const value = Number(bytes || 0);

            if (!Number.isFinite(value) || value <= 0) {
                return "0 B";
            }

            if (value < 1024) {
                return `${value} B`;
            }

            if (value < 1024 * 1024) {
                return `${(value / 1024).toFixed(1)} KB`;
            }

            return `${(value / (1024 * 1024)).toFixed(2)} MB`;
        },


        number(value) {
            const parsed = Number(value || 0);
            return Number.isFinite(parsed) ? parsed.toLocaleString() : "0";
        },


        cloneData(value) {
            try {
                return JSON.parse(JSON.stringify(value));
            } catch (error) {
                return null;
            }
        },


        escapeHTML(value) {
            return AuthorOSHelpers.escapeHTML(value);
        }

    };

})();