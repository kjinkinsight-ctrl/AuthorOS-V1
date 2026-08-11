/*
=========================================================
AUTHOROS
MANUSCRIPT MODULE
Milestone 05
=========================================================
*/

(function () {

    "use strict";

    window.AuthorOSManuscript = {

        name: "manuscript",

        core: null,
        container: null,
        modalContainer: null,

        activeProjectId: null,
        activeChapterId: null,

        editorDraftContent: "",

        dirty: false,
        saveState: "saved",

        autosaveDelay: 1000,
        autosaveTimer: null,

        saveInFlight: false,
        pendingSaveRequested: false,
        pendingManualSaveRequested: false,
        draftVersion: 0,
        lastSavedVersion: 0,
        lastFailedSavePayload: null,

        focusMode: false,

        sprint: {
            durationMinutes: 15,
            remainingSeconds: 900,
            running: false,
            intervalId: null,
            elapsedSeconds: 0
        },

        editorSettings: {
            fontFamily: "merriweather",
            fontSize: 18,
            lineHeight: 1.65,
            editorWidth: "normal",
            spellcheck: true
        },


        initialize(core) {

            this.core = core;
            this.modalContainer = document.getElementById("modal-container");

            this.loadEditorSettings();

            this.core.events.on("navigation:changed", navigation => {

                if (navigation?.route !== "manuscript") {
                    this.flushPendingChanges("route-change");
                    this.stopAutosaveTimer();
                    this.stopSprintInterval();
                    this.focusMode = false;
                }

            });

            window.addEventListener("beforeunload", event => {

                if (!this.dirty || !this.activeProjectId) {
                    return;
                }

                const saved = this.flushPendingChanges("beforeunload");

                if (!saved) {
                    event.preventDefault();
                    event.returnValue = "";
                }

            });

        },


        render(container) {

            if (!container) {
                return;
            }

            this.container = container;

            const project = this.getActiveProject();

            if (!project) {
                container.innerHTML = this.renderMissingProjectState();
                this.bindMissingProjectEvents(container);
                return;
            }

            const hydrated = this.ensureManuscriptShape(project);

            if (hydrated.changed) {
                this.persistProject(hydrated.project, "manuscript-hydrate");
            }

            const freshProject = this.getProjectById(project.id) || hydrated.project;
            const chapters = this.getChapters(freshProject);

            this.activeProjectId = freshProject.id;

            if (!this.activeChapterId || !chapters.some(chapter => chapter.id === this.activeChapterId)) {
                this.activeChapterId = this.getPreferredChapterId(freshProject, chapters);
            }

            const activeChapter = this.getChapterById(freshProject, this.activeChapterId);

            this.editorDraftContent = activeChapter
                ? String(activeChapter.content || "")
                : "";

            container.innerHTML = this.renderStudio(freshProject, chapters, activeChapter);

            this.bindStudioEvents(container, freshProject.id);
            this.updateSaveStatus(this.saveState);
            this.updateWordCountDisplay(freshProject, activeChapter);
            this.updateGoalDisplay(freshProject);
            this.updateSprintDisplay();

            if (this.focusMode) {
                container.classList.add("manuscript-focus-mode");
            }

            const editor = container.querySelector("#manuscript-editor");
            editor?.focus();

        },


        getActiveProject() {

            const fromState = this.core.state.get("currentProject");

            if (fromState && typeof fromState === "object") {
                return fromState;
            }

            const activeProjectId = this.core.storage.loadActiveProjectId();

            if (!activeProjectId) {
                return null;
            }

            return this.getProjectById(activeProjectId);

        },


        getProjectById(projectId) {

            const projects = this.core.state.get("projects");

            if (!Array.isArray(projects)) {
                return null;
            }

            return projects.find(project => project.id === projectId) || null;

        },


        ensureManuscriptShape(project) {

            const clone = this.cloneData(project);

            if (!clone) {
                return { project, changed: false };
            }

            const now = new Date().toISOString();
            let changed = false;

            if (!clone.manuscript || typeof clone.manuscript !== "object") {
                clone.manuscript = {};
                changed = true;
            }

            if (!Array.isArray(clone.manuscript.chapters)) {
                clone.manuscript.chapters = [];
                changed = true;
            }

            if (typeof clone.manuscript.goalTargetWords !== "number") {
                clone.manuscript.goalTargetWords = Math.max(
                    0,
                    Number(clone.targetWords || clone.targetWordCount || 0) || 0
                );
                changed = true;
            }

            clone.manuscript.chapters = clone.manuscript.chapters.map((chapter, index) => {

                const normalized = this.normalizeChapter(chapter, clone.id, index + 1, now);

                if (JSON.stringify(chapter) !== JSON.stringify(normalized)) {
                    changed = true;
                }

                return normalized;

            }).sort((a, b) => a.order - b.order)
                .map((chapter, index) => ({
                    ...chapter,
                    order: index + 1
                }));

            const chapterCount = clone.manuscript.chapters.length;
            const totalWords = this.getTotalWordCount(clone.manuscript.chapters);

            if (!clone.statistics || typeof clone.statistics !== "object") {
                clone.statistics = {
                    words: totalWords,
                    characters: 0,
                    chapters: chapterCount,
                    scenes: 0
                };
                changed = true;
            }

            if (Number(clone.statistics.words || 0) !== totalWords) {
                clone.statistics.words = totalWords;
                changed = true;
            }

            if (Number(clone.statistics.chapters || 0) !== chapterCount) {
                clone.statistics.chapters = chapterCount;
                changed = true;
            }

            if (!clone.updatedAt) {
                clone.updatedAt = now;
                changed = true;
            }

            if (!clone.lastModified) {
                clone.lastModified = clone.updatedAt;
                changed = true;
            }

            return { project: clone, changed };

        },


        normalizeChapter(chapter, projectId, fallbackOrder, fallbackDate) {

            const safe = chapter && typeof chapter === "object"
                ? chapter
                : {};

            const title = String(safe.title || "").trim() || `Chapter ${fallbackOrder}`;
            const content = String(safe.content || "");

            const createdAt = this.normalizeDateValue(safe.createdAt, fallbackDate);
            const updatedAt = this.normalizeDateValue(safe.updatedAt, createdAt);

            return {
                id: typeof safe.id === "string" && safe.id.trim()
                    ? safe.id.trim()
                    : AuthorOSHelpers.generateId("chapter"),
                projectId,
                title,
                order: Number.isFinite(Number(safe.order))
                    ? Math.max(1, Math.trunc(Number(safe.order)))
                    : fallbackOrder,
                content,
                wordCount: this.countWords(content),
                createdAt,
                updatedAt
            };

        },


        normalizeDateValue(value, fallback) {

            if (value === null || value === undefined || value === "") {
                return fallback;
            }

            const date = new Date(value);

            if (Number.isNaN(date.getTime())) {
                return fallback;
            }

            return date.toISOString();

        },


        renderMissingProjectState() {

            return `
                <section class="manuscript-missing-project">
                    <div class="empty-view-icon">*</div>
                    <p class="eyebrow">WRITING EDITOR</p>
                    <h1>No active project</h1>
                    <p>Open a project from Story Library to begin writing.</p>
                    <div class="manuscript-missing-actions">
                        <button type="button" class="button button-primary" data-action="return-to-library">
                            Open Story Library
                        </button>
                    </div>
                </section>
            `;

        },


        bindMissingProjectEvents(container) {

            container.querySelector('[data-action="return-to-library"]')
                ?.addEventListener("click", event => {
                    event.preventDefault();
                    this.core.navigation.navigate("projects");
                });

        },


        renderStudio(project, chapters, activeChapter) {

            const totalWords = this.getTotalWordCount(chapters);
            const targetWords = this.getGoalTargetWords(project);
            const chapterWords = activeChapter ? activeChapter.wordCount : 0;
            const progress = this.getGoalProgress(totalWords, targetWords);

            return `
                <section class="manuscript-studio-view">

                    <header class="manuscript-studio-header">
                        <div>
                            <p class="eyebrow">WRITING EDITOR</p>
                            <h1 title="${this.escapeHTML(project.name || project.title || "Project")}">
                                ${this.escapeHTML(project.name || project.title || "Project")}
                            </h1>
                            <p class="manuscript-studio-subtitle">
                                ${chapters.length} chapter${chapters.length === 1 ? "" : "s"} | ${totalWords.toLocaleString()} words
                            </p>
                        </div>

                        <div class="manuscript-studio-header-actions">
                            <span class="manuscript-save-status" id="manuscript-save-status" aria-live="polite">Saved</span>
                            ${
                                this.saveState === "error"
                                    ? `
                                        <button type="button" class="button button-danger" data-action="retry-save">
                                            Retry Save
                                        </button>
                                    `
                                    : ""
                            }
                            <button type="button" class="button button-secondary" data-action="toggle-focus-mode">
                                ${this.focusMode ? "Exit Focus" : "Focus Mode"}
                            </button>
                            <button type="button" class="button button-secondary" data-action="save-manuscript">
                                Save
                            </button>
                            <button type="button" class="button button-secondary" data-action="return-to-project">
                                Return to Project
                            </button>
                        </div>
                    </header>

                    <div class="manuscript-studio-layout">

                        <aside class="manuscript-chapter-panel" aria-label="Chapter list">
                            <div class="manuscript-panel-header">
                                <h2>Chapters</h2>
                                <button type="button" class="button button-primary" data-action="create-chapter">
                                    + Chapter
                                </button>
                            </div>

                            ${
                                chapters.length
                                    ? `
                                        <ol class="manuscript-chapter-list">
                                            ${chapters.map(chapter => this.renderChapterListItem(chapter, activeChapter?.id)).join("")}
                                        </ol>
                                    `
                                    : `
                                        <div class="manuscript-empty-state">
                                            <h3>No chapters yet</h3>
                                            <p>Create your first chapter to begin writing.</p>
                                            <button type="button" class="button button-primary" data-action="create-chapter">
                                                Create Chapter
                                            </button>
                                        </div>
                                    `
                            }
                        </aside>

                        <section class="manuscript-editor-panel" aria-label="Writing editor">
                            ${
                                activeChapter
                                    ? this.renderEditor(project, activeChapter)
                                    : `
                                        <div class="manuscript-empty-editor">
                                            <h2>Select a chapter</h2>
                                            <p>Create or open a chapter from the left panel.</p>
                                        </div>
                                    `
                            }
                        </section>

                        <aside class="manuscript-meta-panel" aria-label="Writing controls">
                            <section class="manuscript-stat-card">
                                <h3>Chapter Words</h3>
                                <p id="chapter-word-count">${chapterWords.toLocaleString()}</p>
                            </section>

                            <section class="manuscript-stat-card">
                                <h3>Total Words</h3>
                                <p id="total-word-count">${totalWords.toLocaleString()}</p>
                            </section>

                            <section class="manuscript-goal-card">
                                <h3>Writing Goal</h3>
                                <label for="manuscript-goal-target">Target Words</label>
                                <input id="manuscript-goal-target" type="number" min="0" step="1" value="${targetWords}" />
                                <p id="manuscript-goal-progress">${progress.label}</p>
                                <progress id="manuscript-goal-bar" max="100" value="${progress.percent}"></progress>
                                <button type="button" class="button button-secondary" data-action="save-goal">Update Goal</button>
                            </section>

                            <section class="manuscript-sprint-card">
                                <h3>Writing Sprint</h3>
                                <label for="sprint-duration-input">Duration (minutes)</label>
                                <input id="sprint-duration-input" type="number" min="1" max="240" step="1" value="${this.sprint.durationMinutes}" />
                                <p id="sprint-time-display">Time Remaining: ${this.getSprintTimeLabel()}</p>
                                <p id="sprint-elapsed-display">Elapsed: ${this.formatSeconds(this.sprint.elapsedSeconds)}</p>
                                <div class="manuscript-sprint-actions">
                                    <button type="button" class="button button-primary" data-action="start-sprint">Start</button>
                                    <button type="button" class="button button-secondary" data-action="pause-sprint">Pause</button>
                                    <button type="button" class="button button-secondary" data-action="resume-sprint">Resume</button>
                                    <button type="button" class="button button-secondary" data-action="reset-sprint">Reset</button>
                                </div>
                            </section>

                            <section class="manuscript-settings-card">
                                <h3>Editor Settings</h3>
                                <label for="editor-font-family">Font Family</label>
                                <select id="editor-font-family">
                                    ${this.getEditorFontFamilyOptionsMarkup()}
                                </select>

                                <label for="editor-font-size">Font Size</label>
                                <input id="editor-font-size" type="number" min="14" max="28" step="1" value="${this.editorSettings.fontSize}" />

                                <label for="editor-line-height">Line Height</label>
                                <select id="editor-line-height">
                                    ${[1.4,1.5,1.6,1.65,1.7,1.8].map(value => `
                                        <option value="${value}" ${Number(this.editorSettings.lineHeight) === value ? "selected" : ""}>${value}</option>
                                    `).join("")}
                                </select>

                                <label for="editor-width">Editor Width</label>
                                <select id="editor-width">
                                    <option value="narrow" ${this.editorSettings.editorWidth === "narrow" ? "selected" : ""}>Narrow</option>
                                    <option value="normal" ${this.editorSettings.editorWidth === "normal" ? "selected" : ""}>Normal</option>
                                    <option value="wide" ${this.editorSettings.editorWidth === "wide" ? "selected" : ""}>Wide</option>
                                </select>

                                <label class="manuscript-checkbox-label">
                                    <input id="editor-spellcheck" type="checkbox" ${this.editorSettings.spellcheck ? "checked" : ""} />
                                    <span>Enable Spellcheck</span>
                                </label>

                                <button type="button" class="button button-secondary" data-action="save-editor-settings">Save Settings</button>
                            </section>
                        </aside>

                    </div>

                </section>
            `;

        },


        renderChapterListItem(chapter, activeChapterId) {

            const isActive = chapter.id === activeChapterId;

            return `
                <li class="manuscript-chapter-item ${isActive ? "active" : ""}" data-chapter-id="${this.escapeHTML(chapter.id)}">
                    <button type="button" class="manuscript-chapter-open" data-action="open-chapter" data-chapter-id="${this.escapeHTML(chapter.id)}">
                        <span class="manuscript-chapter-order">${chapter.order}.</span>
                        <span class="manuscript-chapter-title">${this.escapeHTML(chapter.title)}</span>
                        <span class="manuscript-chapter-words">${chapter.wordCount.toLocaleString()} words</span>
                    </button>

                    <div class="manuscript-chapter-actions">
                        <button type="button" class="chapter-action" data-action="rename-chapter" data-chapter-id="${this.escapeHTML(chapter.id)}" aria-label="Rename chapter">Rename</button>
                        <button type="button" class="chapter-action" data-action="move-chapter-up" data-chapter-id="${this.escapeHTML(chapter.id)}" aria-label="Move chapter up">↑</button>
                        <button type="button" class="chapter-action" data-action="move-chapter-down" data-chapter-id="${this.escapeHTML(chapter.id)}" aria-label="Move chapter down">↓</button>
                        <button type="button" class="chapter-action chapter-action-danger" data-action="delete-chapter" data-chapter-id="${this.escapeHTML(chapter.id)}" aria-label="Delete chapter">Delete</button>
                    </div>
                </li>
            `;

        },


        renderEditor(project, chapter) {

            const widthClass =
                this.editorSettings.editorWidth === "narrow"
                    ? "manuscript-editor-width-narrow"
                    : this.editorSettings.editorWidth === "wide"
                        ? "manuscript-editor-width-wide"
                        : "manuscript-editor-width-normal";

            return `
                <header class="manuscript-editor-header">
                    <h2>${this.escapeHTML(chapter.title)}</h2>
                    <div class="manuscript-editor-nav">
                        <button type="button" class="button button-secondary" data-action="open-prev-chapter">Previous</button>
                        <button type="button" class="button button-secondary" data-action="open-next-chapter">Next</button>
                    </div>
                </header>

                <div class="manuscript-editor-toolbar" role="toolbar" aria-label="Editor toolbar">
                    <button type="button" class="button button-secondary" data-action="editor-undo" aria-label="Undo">Undo</button>
                    <button type="button" class="button button-secondary" data-action="editor-redo" aria-label="Redo">Redo</button>
                    <span class="manuscript-editor-toolbar-meta">Chapter words: <strong id="toolbar-word-count">${this.countWords(chapter.content).toLocaleString()}</strong></span>
                </div>

                <div class="manuscript-editor-wrap ${widthClass}" style="--editor-font-size:${Number(this.editorSettings.fontSize)}px; --editor-line-height:${Number(this.editorSettings.lineHeight)}; --editor-font-family:${this.escapeHTML(this.getEditorFontFamilyStack(this.editorSettings.fontFamily))};">
                    <textarea
                        id="manuscript-editor"
                        class="manuscript-editor"
                        spellcheck="${this.editorSettings.spellcheck ? "true" : "false"}"
                        aria-label="Manuscript editor"
                        placeholder="Start writing..."
                    >${this.escapeHTML(chapter.content)}</textarea>
                </div>

                <p class="manuscript-editor-hint">
                    Shortcuts: Ctrl/Cmd+S save, Ctrl/Cmd+Z undo, Ctrl/Cmd+Shift+Z or Ctrl/Cmd+Y redo, Esc exits Focus Mode.
                </p>
            `;

        },


        bindStudioEvents(container, projectId) {

            container.querySelectorAll('[data-action="return-to-project"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.leaveStudioToProject();
                });
            });

            container.querySelectorAll('[data-action="save-manuscript"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.requestSave({ manual: true, reason: "manual" });
                });
            });

            container.querySelectorAll('[data-action="retry-save"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.retryFailedSave();
                });
            });

            container.querySelectorAll('[data-action="toggle-focus-mode"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.toggleFocusMode();
                });
            });

            container.querySelectorAll('[data-action="create-chapter"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.createChapter(projectId);
                });
            });

            container.querySelectorAll('[data-action="open-chapter"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.openChapter(projectId, button.dataset.chapterId);
                });
            });

            container.querySelectorAll('[data-action="rename-chapter"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.showRenameChapterModal(projectId, button.dataset.chapterId);
                });
            });

            container.querySelectorAll('[data-action="move-chapter-up"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.reorderChapter(projectId, button.dataset.chapterId, -1);
                });
            });

            container.querySelectorAll('[data-action="move-chapter-down"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.reorderChapter(projectId, button.dataset.chapterId, 1);
                });
            });

            container.querySelectorAll('[data-action="delete-chapter"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.confirmDeleteChapter(projectId, button.dataset.chapterId);
                });
            });

            container.querySelectorAll('[data-action="open-prev-chapter"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.openRelativeChapter(projectId, -1);
                });
            });

            container.querySelectorAll('[data-action="open-next-chapter"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.openRelativeChapter(projectId, 1);
                });
            });

            container.querySelectorAll('[data-action="editor-undo"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.runEditorCommand("undo");
                });
            });

            container.querySelectorAll('[data-action="editor-redo"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.runEditorCommand("redo");
                });
            });

            const editor = container.querySelector("#manuscript-editor");

            if (editor) {

                editor.addEventListener("focus", () => {
                    editor.classList.add("is-focused");
                });

                editor.addEventListener("blur", () => {
                    editor.classList.remove("is-focused");
                });

                editor.addEventListener("input", () => {
                    this.editorDraftContent = editor.value;
                    this.markDirty();
                    this.updateDraftWordCount(editor.value);
                    this.scheduleAutosave();
                });

                editor.addEventListener("keydown", event => {

                    const key = event.key.toLowerCase();
                    const hasMod = event.ctrlKey || event.metaKey;

                    if (hasMod && key === "s") {
                        event.preventDefault();
                        this.requestSave({ manual: true, reason: "shortcut-save" });
                        return;
                    }

                    if (hasMod && key === "y") {
                        event.preventDefault();
                        this.runEditorCommand("redo");
                        return;
                    }

                    if (hasMod && event.shiftKey && key === "z") {
                        event.preventDefault();
                        this.runEditorCommand("redo");
                        return;
                    }

                    if (key === "escape" && this.focusMode) {
                        event.preventDefault();
                        this.toggleFocusMode(false);
                    }

                });

            }

            const goalInput = container.querySelector("#manuscript-goal-target");
            const durationInput = container.querySelector("#sprint-duration-input");

            container.querySelector('[data-action="save-goal"]')
                ?.addEventListener("click", event => {
                    event.preventDefault();
                    this.saveWritingGoal(projectId, goalInput?.value);
                });

            durationInput?.addEventListener("change", () => {
                this.updateSprintDuration(durationInput.value);
            });

            container.querySelector('[data-action="start-sprint"]')
                ?.addEventListener("click", event => {
                    event.preventDefault();
                    this.startSprint();
                });

            container.querySelector('[data-action="pause-sprint"]')
                ?.addEventListener("click", event => {
                    event.preventDefault();
                    this.pauseSprint();
                });

            container.querySelector('[data-action="resume-sprint"]')
                ?.addEventListener("click", event => {
                    event.preventDefault();
                    this.resumeSprint();
                });

            container.querySelector('[data-action="reset-sprint"]')
                ?.addEventListener("click", event => {
                    event.preventDefault();
                    this.resetSprint();
                });

            container.querySelector('[data-action="save-editor-settings"]')
                ?.addEventListener("click", event => {
                    event.preventDefault();
                    this.saveEditorSettingsFromUI();
                });

        },


        runEditorCommand(command) {

            const editor = this.container?.querySelector("#manuscript-editor");

            if (!editor) {
                return;
            }

            editor.focus();

            try {
                document.execCommand(command);
            } catch (error) {
                console.warn("Editor command failed:", command, error);
            }

            this.editorDraftContent = editor.value;
            this.markDirty();
            this.scheduleAutosave();

        },


        getChapters(project) {

            if (!project?.manuscript?.chapters || !Array.isArray(project.manuscript.chapters)) {
                return [];
            }

            return [...project.manuscript.chapters]
                .sort((left, right) => left.order - right.order)
                .map((chapter, index) => ({
                    ...chapter,
                    order: index + 1,
                    wordCount: this.countWords(chapter.content || "")
                }));

        },


        getChapterById(project, chapterId) {

            if (!project || !chapterId) {
                return null;
            }

            return this.getChapters(project)
                .find(chapter => chapter.id === chapterId) || null;

        },


        getPreferredChapterId(project, chapters) {

            const lastOpened = project?.manuscript?.lastOpenedChapterId;

            if (lastOpened && chapters.some(chapter => chapter.id === lastOpened)) {
                return lastOpened;
            }

            return chapters.length
                ? chapters[0].id
                : null;

        },


        createChapter(projectId) {

            if (!this.flushPendingChanges("chapter-create")) {
                return;
            }

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const hydrated = this.ensureManuscriptShape(project);
            const next = this.cloneData(hydrated.project);

            if (!next) {
                this.core.notify("Unable to create chapter.", "error");
                return;
            }

            const chapters = this.getChapters(next);
            const nextOrder = chapters.length + 1;
            const now = new Date().toISOString();

            const newChapter = {
                id: AuthorOSHelpers.generateId("chapter"),
                projectId,
                title: `Chapter ${nextOrder}`,
                order: nextOrder,
                content: "",
                wordCount: 0,
                createdAt: now,
                updatedAt: now
            };

            next.manuscript.chapters = [...chapters, newChapter];
            next.manuscript.lastOpenedChapterId = newChapter.id;
            next.updatedAt = now;
            next.lastModified = now;
            next.statistics = {
                ...(next.statistics || {}),
                words: this.getTotalWordCount(next.manuscript.chapters),
                chapters: next.manuscript.chapters.length
            };

            if (!this.persistProject(next, "chapter-create")) {
                this.updateSaveStatus("error");
                this.core.notify("Failed to create chapter.", "error");
                return;
            }

            this.activeChapterId = newChapter.id;
            this.editorDraftContent = "";
            this.dirty = false;
            this.draftVersion += 1;
            this.lastSavedVersion = this.draftVersion;
            this.updateSaveStatus("saved");

            this.core.events.emit("chapter:created", {
                projectId,
                chapterId: newChapter.id,
                chapter: newChapter
            });

            this.core.notify("Chapter created.", "success");
            this.render(this.container);

        },


        openChapter(projectId, chapterId) {

            if (!chapterId || this.activeChapterId === chapterId) {
                return;
            }

            if (!this.flushPendingChanges("chapter-switch")) {
                this.core.notify("Please resolve save issues before switching chapters.", "error");
                return;
            }

            const project = this.getProjectById(projectId);
            const chapter = this.getChapterById(project, chapterId);

            if (!chapter) {
                this.core.notify("Chapter could not be found.", "error");
                return;
            }

            const nextProject = this.cloneData(project);

            if (!nextProject) {
                return;
            }

            nextProject.manuscript.lastOpenedChapterId = chapterId;

            const now = new Date().toISOString();
            nextProject.updatedAt = now;
            nextProject.lastModified = now;

            this.persistProject(nextProject, "chapter-open");

            this.activeChapterId = chapterId;
            this.editorDraftContent = chapter.content || "";
            this.dirty = false;
            this.lastFailedSavePayload = null;
            this.updateSaveStatus("saved");

            this.render(this.container);

        },


        openRelativeChapter(projectId, delta) {

            const project = this.getProjectById(projectId);
            const chapters = this.getChapters(project);

            if (!chapters.length || !this.activeChapterId) {
                return;
            }

            const index = chapters.findIndex(chapter => chapter.id === this.activeChapterId);

            if (index === -1) {
                return;
            }

            const targetIndex = index + delta;

            if (targetIndex < 0 || targetIndex >= chapters.length) {
                return;
            }

            this.openChapter(projectId, chapters[targetIndex].id);

        },


        showRenameChapterModal(projectId, chapterId) {

            const project = this.getProjectById(projectId);
            const chapter = this.getChapterById(project, chapterId);

            if (!chapter) {
                this.core.notify("Chapter could not be found.", "error");
                return;
            }

            if (!this.modalContainer) {
                this.modalContainer = document.getElementById("modal-container");
            }

            if (!this.modalContainer) {
                return;
            }

            this.modalContainer.innerHTML = `
                <div class="project-modal-backdrop">
                    <section class="project-modal" role="dialog" aria-modal="true" aria-labelledby="rename-chapter-title">
                        <header class="project-modal-header">
                            <div>
                                <p class="eyebrow">MANUSCRIPT</p>
                                <h2 id="rename-chapter-title">Rename Chapter</h2>
                            </div>
                            <button type="button" class="project-modal-close" data-action="close-rename-modal" aria-label="Close rename chapter">×</button>
                        </header>

                        <form id="rename-chapter-form" class="project-form" novalidate>
                            <div class="project-form-grid">
                                <label class="form-field full-width" for="rename-chapter-input">
                                    <span>Chapter Title</span>
                                    <input id="rename-chapter-input" name="title" type="text" value="${this.escapeHTML(chapter.title)}" required />
                                </label>
                            </div>

                            <footer class="project-modal-footer">
                                <button type="button" class="button button-secondary" data-action="close-rename-modal">Cancel</button>
                                <button type="submit" class="button button-primary">Save</button>
                            </footer>
                        </form>
                    </section>
                </div>
            `;

            this.modalContainer.classList.add("active");

            this.modalContainer.querySelectorAll('[data-action="close-rename-modal"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.closeModal();
                });
            });

            this.bindModalBackdrop();

            this.modalContainer.querySelector("#rename-chapter-form")
                ?.addEventListener("submit", event => {
                    event.preventDefault();

                    const formData = new FormData(event.currentTarget);
                    const title = String(formData.get("title") || "").trim();

                    if (!title) {
                        this.core.notify("Chapter title is required.", "error");
                        return;
                    }

                    this.renameChapter(projectId, chapterId, title);
                    this.closeModal();
                });

        },


        renameChapter(projectId, chapterId, title) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const next = this.cloneData(project);

            if (!next) {
                return;
            }

            const now = new Date().toISOString();
            const chapters = this.getChapters(next);
            const index = chapters.findIndex(chapter => chapter.id === chapterId);

            if (index === -1) {
                this.core.notify("Chapter could not be found.", "error");
                return;
            }

            chapters[index] = {
                ...chapters[index],
                title,
                updatedAt: now
            };

            next.manuscript.chapters = chapters;
            next.updatedAt = now;
            next.lastModified = now;

            if (!this.persistProject(next, "chapter-rename")) {
                this.updateSaveStatus("error");
                this.core.notify("Failed to rename chapter.", "error");
                return;
            }

            this.core.notify("Chapter renamed.", "success");
            this.render(this.container);

        },


        reorderChapter(projectId, chapterId, delta) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const next = this.cloneData(project);

            if (!next) {
                return;
            }

            const chapters = this.getChapters(next);
            const index = chapters.findIndex(chapter => chapter.id === chapterId);

            if (index === -1) {
                this.core.notify("Chapter could not be found.", "error");
                return;
            }

            const target = index + delta;

            if (target < 0 || target >= chapters.length) {
                return;
            }

            const temp = chapters[index];
            chapters[index] = chapters[target];
            chapters[target] = temp;

            const now = new Date().toISOString();

            next.manuscript.chapters = chapters.map((chapter, orderIndex) => ({
                ...chapter,
                order: orderIndex + 1,
                updatedAt: now
            }));

            next.updatedAt = now;
            next.lastModified = now;

            if (!this.persistProject(next, "chapter-reorder")) {
                this.updateSaveStatus("error");
                this.core.notify("Failed to reorder chapters.", "error");
                return;
            }

            this.core.notify("Chapter order updated.", "success");
            this.render(this.container);

        },


        confirmDeleteChapter(projectId, chapterId) {

            const project = this.getProjectById(projectId);
            const chapter = this.getChapterById(project, chapterId);

            if (!chapter) {
                this.core.notify("Chapter could not be found.", "error");
                return;
            }

            if (!this.core.modal || typeof this.core.modal.open !== "function") {
                this.core.notify("Delete confirmation is unavailable.", "error");
                return;
            }

            this.core.modal.open({
                title: "Delete Chapter",
                content: `
                    <p>Delete \"${this.escapeHTML(chapter.title)}\"?</p>
                    <p>This permanently deletes chapter content.</p>
                `,
                confirmText: "Delete",
                onConfirm: () => {
                    this.deleteChapter(projectId, chapterId);
                }
            });

        },


        deleteChapter(projectId, chapterId) {

            if (!this.flushPendingChanges("chapter-delete")) {
                return;
            }

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const next = this.cloneData(project);

            if (!next) {
                return;
            }

            const chapters = this.getChapters(next);
            const currentIndex = chapters.findIndex(chapter => chapter.id === chapterId);

            if (currentIndex === -1) {
                this.core.notify("Chapter could not be found.", "error");
                return;
            }

            const filtered = chapters.filter(chapter => chapter.id !== chapterId)
                .map((chapter, index) => ({
                    ...chapter,
                    order: index + 1
                }));

            const now = new Date().toISOString();

            next.manuscript.chapters = filtered;
            next.updatedAt = now;
            next.lastModified = now;
            next.statistics = {
                ...(next.statistics || {}),
                words: this.getTotalWordCount(filtered),
                chapters: filtered.length
            };

            let nextActiveId = null;

            if (filtered.length) {
                const fallbackIndex = Math.min(currentIndex, filtered.length - 1);
                nextActiveId = filtered[fallbackIndex].id;
            }

            next.manuscript.lastOpenedChapterId = nextActiveId;

            if (!this.persistProject(next, "chapter-delete")) {
                this.updateSaveStatus("error");
                this.core.notify("Failed to delete chapter.", "error");
                return;
            }

            this.activeChapterId = nextActiveId;
            this.editorDraftContent = nextActiveId
                ? (filtered.find(chapter => chapter.id === nextActiveId)?.content || "")
                : "";
            this.dirty = false;
            this.updateSaveStatus("saved");

            this.core.notify("Chapter deleted.", "success");
            this.render(this.container);

        },


        markDirty() {

            this.dirty = true;
            this.draftVersion += 1;
            this.updateSaveStatus("unsaved");

        },


        scheduleAutosave() {

            this.stopAutosaveTimer();

            this.autosaveTimer = window.setTimeout(() => {
                this.requestSave({ manual: false, reason: "autosave" });
            }, this.autosaveDelay);

        },


        stopAutosaveTimer() {

            if (this.autosaveTimer) {
                clearTimeout(this.autosaveTimer);
                this.autosaveTimer = null;
            }

        },


        flushPendingChanges(reason) {

            this.stopAutosaveTimer();

            if (!this.dirty) {
                return true;
            }

            return this.requestSave({ manual: false, reason: reason || "flush" });

        },


        requestSave(options = {}) {

            if (!this.activeProjectId || !this.activeChapterId) {
                this.dirty = false;
                this.updateSaveStatus("saved");
                return true;
            }

            if (!this.dirty && !options.manual) {
                this.updateSaveStatus("saved");
                return true;
            }

            this.pendingSaveRequested = true;

            if (options.manual) {
                this.pendingManualSaveRequested = true;
            }

            return this.processSaveQueue(options.reason || "save");

        },


        processSaveQueue(reason) {

            if (this.saveInFlight) {
                return true;
            }

            let allSavesSucceeded = true;

            while (this.pendingSaveRequested) {

                this.pendingSaveRequested = false;

                const snapshot = this.buildSaveSnapshot(reason);

                if (!snapshot) {
                    this.updateSaveStatus("error");
                    return false;
                }

                this.saveInFlight = true;
                this.updateSaveStatus("saving");

                const saved = this.persistProject(snapshot.project, snapshot.source);

                this.saveInFlight = false;

                if (!saved) {

                    this.lastFailedSavePayload = snapshot;
                    this.updateSaveStatus("error");
                    allSavesSucceeded = false;
                    break;

                }

                this.lastFailedSavePayload = null;
                this.lastSavedVersion = snapshot.version;
                this.dirty = this.draftVersion > this.lastSavedVersion;
                this.updateSaveStatus(this.dirty ? "unsaved" : "saved");
                this.updateWordCountDisplay(snapshot.project, snapshot.activeChapter);
                this.updateGoalDisplay(snapshot.project);

                if (this.pendingManualSaveRequested && !this.dirty) {
                    this.core.notify("Manuscript saved.", "success");
                    this.pendingManualSaveRequested = false;
                }

            }

            if (!allSavesSucceeded && this.pendingManualSaveRequested) {
                this.core.notify("Save failed. Retry when storage is available.", "error");
                this.pendingManualSaveRequested = false;
            }

            return allSavesSucceeded;

        },


        buildSaveSnapshot(reason) {

            const project = this.getProjectById(this.activeProjectId);

            if (!project) {
                return null;
            }

            const next = this.cloneData(project);

            if (!next) {
                return null;
            }

            const content = this.getEditorContentForSave();
            const now = new Date().toISOString();

            const chapters = this.getChapters(next);
            const index = chapters.findIndex(chapter => chapter.id === this.activeChapterId);

            if (index === -1) {
                this.core.notify("Active chapter could not be found.", "error");
                return null;
            }

            chapters[index] = {
                ...chapters[index],
                content,
                wordCount: this.countWords(content),
                updatedAt: now
            };

            next.manuscript.chapters = chapters;
            next.manuscript.lastOpenedChapterId = this.activeChapterId;
            next.updatedAt = now;
            next.lastModified = now;
            next.statistics = {
                ...(next.statistics || {}),
                words: this.getTotalWordCount(chapters),
                chapters: chapters.length
            };

            return {
                project: next,
                source: reason || "save",
                version: this.draftVersion,
                activeChapter: chapters[index]
            };

        },


        getEditorContentForSave() {

            const editor = this.container?.querySelector("#manuscript-editor");

            if (editor) {
                this.editorDraftContent = editor.value;
            }

            return String(this.editorDraftContent || "");

        },


        retryFailedSave() {

            if (!this.lastFailedSavePayload) {
                this.requestSave({ manual: true, reason: "retry-request" });
                return;
            }

            this.updateSaveStatus("saving");

            const payload = this.lastFailedSavePayload;

            const saved = this.persistProject(payload.project, "retry-save");

            if (!saved) {
                this.updateSaveStatus("error");
                this.core.notify("Save retry failed.", "error");
                return;
            }

            this.lastSavedVersion = Math.max(this.lastSavedVersion, payload.version);
            this.lastFailedSavePayload = null;
            this.dirty = this.draftVersion > this.lastSavedVersion;
            this.updateSaveStatus(this.dirty ? "unsaved" : "saved");

            const latestProject = this.getProjectById(this.activeProjectId) || payload.project;
            const latestChapter = this.getChapterById(latestProject, this.activeChapterId);

            this.updateWordCountDisplay(latestProject, latestChapter);
            this.updateGoalDisplay(latestProject);
            this.core.notify("Save retry succeeded.", "success");
            this.render(this.container);

        },


        updateDraftWordCount(content) {

            const chapterWordsElement = this.container?.querySelector("#chapter-word-count");
            const toolbarWordsElement = this.container?.querySelector("#toolbar-word-count");

            const count = this.countWords(content).toLocaleString();

            if (chapterWordsElement) {
                chapterWordsElement.textContent = count;
            }

            if (toolbarWordsElement) {
                toolbarWordsElement.textContent = count;
            }

        },


        updateWordCountDisplay(project, activeChapter) {

            const chapterWordElement = this.container?.querySelector("#chapter-word-count");
            const totalWordElement = this.container?.querySelector("#total-word-count");
            const toolbarWordsElement = this.container?.querySelector("#toolbar-word-count");

            const chapterWords = Number(activeChapter?.wordCount || 0).toLocaleString();

            if (chapterWordElement) {
                chapterWordElement.textContent = chapterWords;
            }

            if (toolbarWordsElement) {
                toolbarWordsElement.textContent = chapterWords;
            }

            if (totalWordElement) {
                totalWordElement.textContent = this.getTotalWordCount(this.getChapters(project)).toLocaleString();
            }

        },


        updateSaveStatus(state) {

            this.saveState = state;

            const label = state === "saving"
                ? "Saving..."
                : state === "unsaved"
                    ? "Unsaved changes"
                    : state === "error"
                        ? "Save failed"
                        : "Saved";

            const statusElement = this.container?.querySelector("#manuscript-save-status");

            if (statusElement) {
                statusElement.textContent = label;
            }

            this.core.setStatus(label);

        },


        countWords(content) {

            const text = String(content || "").trim();

            if (!text) {
                return 0;
            }

            return text.split(/\s+/).filter(Boolean).length;

        },


        getTotalWordCount(chapters) {

            return (Array.isArray(chapters) ? chapters : []).reduce(
                (sum, chapter) => sum + this.countWords(chapter.content || ""),
                0
            );

        },


        getGoalTargetWords(project) {

            const fromManuscript = Number(project?.manuscript?.goalTargetWords);

            if (Number.isFinite(fromManuscript) && fromManuscript >= 0) {
                return Math.trunc(fromManuscript);
            }

            const fromProject = Number(project?.targetWords ?? project?.targetWordCount);

            return Number.isFinite(fromProject) && fromProject >= 0
                ? Math.trunc(fromProject)
                : 0;

        },


        getGoalProgress(current, target) {

            const safeCurrent = Math.max(0, Number(current) || 0);
            const safeTarget = Math.max(0, Number(target) || 0);

            if (safeTarget === 0) {
                return {
                    percent: 0,
                    label: `${safeCurrent.toLocaleString()} / ${safeTarget.toLocaleString()} words`
                };
            }

            const raw = (safeCurrent / safeTarget) * 100;
            const percent = Math.max(0, Math.min(100, Number.isFinite(raw) ? Math.round(raw) : 0));

            return {
                percent,
                label: `${safeCurrent.toLocaleString()} / ${safeTarget.toLocaleString()} words (${percent}%)`
            };

        },


        saveWritingGoal(projectId, value) {

            const project = this.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const parsed = Number(value);
            const target = Number.isFinite(parsed) && parsed >= 0
                ? Math.trunc(parsed)
                : 0;

            const next = this.cloneData(project);

            if (!next) {
                return;
            }

            next.manuscript.goalTargetWords = target;
            next.targetWords = target;
            next.targetWordCount = target;
            next.updatedAt = new Date().toISOString();
            next.lastModified = next.updatedAt;

            if (!this.persistProject(next, "goal-update")) {
                this.updateSaveStatus("error");
                this.core.notify("Failed to update writing goal.", "error");
                return;
            }

            this.core.notify("Writing goal updated.", "success");
            this.updateGoalDisplay(next);

        },


        updateGoalDisplay(project) {

            const current = this.getTotalWordCount(this.getChapters(project));
            const target = this.getGoalTargetWords(project);
            const progress = this.getGoalProgress(current, target);

            const text = this.container?.querySelector("#manuscript-goal-progress");
            const bar = this.container?.querySelector("#manuscript-goal-bar");

            if (text) {
                text.textContent = progress.label;
            }

            if (bar) {
                bar.value = progress.percent;
            }

        },


        updateSprintDuration(value) {

            const parsed = Number(value);

            if (!Number.isFinite(parsed) || parsed < 1) {
                return;
            }

            this.sprint.durationMinutes = Math.min(240, Math.max(1, Math.trunc(parsed)));

            if (!this.sprint.running) {
                this.sprint.remainingSeconds = this.sprint.durationMinutes * 60;
                this.sprint.elapsedSeconds = 0;
                this.updateSprintDisplay();
            }

        },


        startSprint() {

            this.stopSprintInterval();

            this.sprint.remainingSeconds = this.sprint.durationMinutes * 60;
            this.sprint.elapsedSeconds = 0;
            this.sprint.running = true;

            this.startSprintInterval();
            this.updateSprintDisplay();

        },


        pauseSprint() {

            if (!this.sprint.running) {
                return;
            }

            this.sprint.running = false;
            this.stopSprintInterval();
            this.updateSprintDisplay();

        },


        resumeSprint() {

            if (this.sprint.running || this.sprint.remainingSeconds <= 0) {
                return;
            }

            this.sprint.running = true;
            this.startSprintInterval();
            this.updateSprintDisplay();

        },


        resetSprint() {

            this.sprint.running = false;
            this.stopSprintInterval();
            this.sprint.remainingSeconds = this.sprint.durationMinutes * 60;
            this.sprint.elapsedSeconds = 0;
            this.updateSprintDisplay();

        },


        startSprintInterval() {

            this.stopSprintInterval();

            this.sprint.intervalId = window.setInterval(() => {

                if (!this.sprint.running) {
                    return;
                }

                this.sprint.remainingSeconds = Math.max(0, this.sprint.remainingSeconds - 1);
                this.sprint.elapsedSeconds += 1;

                if (this.sprint.remainingSeconds === 0) {
                    this.sprint.running = false;
                    this.stopSprintInterval();
                    this.core.notify("Writing sprint complete.", "success");
                }

                this.updateSprintDisplay();

            }, 1000);

        },


        stopSprintInterval() {

            if (this.sprint.intervalId) {
                clearInterval(this.sprint.intervalId);
                this.sprint.intervalId = null;
            }

        },


        updateSprintDisplay() {

            const time = this.container?.querySelector("#sprint-time-display");
            const elapsed = this.container?.querySelector("#sprint-elapsed-display");

            if (time) {
                time.textContent = `Time Remaining: ${this.getSprintTimeLabel()}`;
            }

            if (elapsed) {
                elapsed.textContent = `Elapsed: ${this.formatSeconds(this.sprint.elapsedSeconds)}`;
            }

        },


        getSprintTimeLabel() {
            return this.formatSeconds(this.sprint.remainingSeconds);
        },


        formatSeconds(total) {

            const safe = Math.max(0, Math.trunc(Number(total) || 0));
            const minutes = Math.floor(safe / 60);
            const seconds = safe % 60;

            return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;

        },


        toggleFocusMode(force = null) {

            this.focusMode = force === null
                ? !this.focusMode
                : Boolean(force);

            if (this.container) {
                this.container.classList.toggle("manuscript-focus-mode", this.focusMode);
            }

            const toggleButton = this.container?.querySelector('[data-action="toggle-focus-mode"]');

            if (toggleButton) {
                toggleButton.textContent = this.focusMode ? "Exit Focus" : "Focus Mode";
            }

            const editor = this.container?.querySelector("#manuscript-editor");
            editor?.focus();

        },


        leaveStudioToProject() {

            if (!this.flushPendingChanges("leave-manuscript")) {
                this.core.notify("Unable to leave Writing Editor due to save failure.", "error");
                return;
            }

            this.focusMode = false;
            this.core.navigation.navigate("project-workspace");

        },


        persistProject(project, source) {

            const projects = this.core.state.get("projects");

            if (!Array.isArray(projects)) {
                return false;
            }

            const index = projects.findIndex(item => item.id === project.id);

            if (index === -1) {
                return false;
            }

            const next = [...projects];
            next[index] = project;

            const projectsModule = this.core.registry.get("projects");

            if (projectsModule && typeof projectsModule.saveProjects === "function") {

                const saved = projectsModule.saveProjects(next, { source: source || "manuscript" });

                if (!saved) {
                    return false;
                }

                const syncedProject = this.getProjectById(project.id) || project;
                this.core.state.set("currentProject", syncedProject);
                this.core.storage.saveActiveProjectId(project.id);

                return true;

            }

            const saved = this.core.storage.saveProjects(next);

            if (!saved) {
                return false;
            }

            this.core.state.set("projects", next);
            this.core.state.set("currentProject", project);
            this.core.storage.saveActiveProjectId(project.id);
            this.core.events.emit("storage:changed");

            return true;

        },


        loadEditorSettings() {

            const settings = this.core?.state?.get("settings") || this.core?.storage?.loadSettings?.() || {};
            const source = settings?.editor || settings?.manuscriptEditor;

            if (!source || typeof source !== "object") {
                return;
            }

            const fontSize = Number(source.fontSize);
            const lineHeight = Number(source.lineHeight);
            const fontFamily = String(source.fontFamily || "").trim();

            if (this.getEditorFontFamilies().some(item => item.value === fontFamily)) {
                this.editorSettings.fontFamily = fontFamily;
            }

            if (Number.isFinite(fontSize) && fontSize >= 14 && fontSize <= 28) {
                this.editorSettings.fontSize = Math.trunc(fontSize);
            }

            if (Number.isFinite(lineHeight) && lineHeight >= 1.3 && lineHeight <= 2) {
                this.editorSettings.lineHeight = lineHeight;
            }

            if (["narrow", "normal", "wide"].includes(String(source.editorWidth))) {
                this.editorSettings.editorWidth = String(source.editorWidth);
            }

            if (typeof source.spellcheck === "boolean") {
                this.editorSettings.spellcheck = source.spellcheck;
            }

        },


        saveEditorSettingsFromUI() {

            const fontInput = this.container?.querySelector("#editor-font-size");
            const lineHeightInput = this.container?.querySelector("#editor-line-height");
            const widthInput = this.container?.querySelector("#editor-width");
            const spellcheckInput = this.container?.querySelector("#editor-spellcheck");
            const fontFamilyInput = this.container?.querySelector("#editor-font-family");

            const parsedFont = Number(fontInput?.value);
            const parsedLineHeight = Number(lineHeightInput?.value);

            this.editorSettings.fontSize = Number.isFinite(parsedFont)
                ? Math.min(28, Math.max(14, Math.trunc(parsedFont)))
                : this.editorSettings.fontSize;

            this.editorSettings.lineHeight = Number.isFinite(parsedLineHeight)
                ? Math.min(2, Math.max(1.3, parsedLineHeight))
                : this.editorSettings.lineHeight;

            this.editorSettings.editorWidth = ["narrow", "normal", "wide"].includes(widthInput?.value)
                ? widthInput.value
                : this.editorSettings.editorWidth;

            this.editorSettings.spellcheck = Boolean(spellcheckInput?.checked);

            this.editorSettings.fontFamily = this.getEditorFontFamilies().some(item => item.value === fontFamilyInput?.value)
                ? String(fontFamilyInput.value)
                : this.editorSettings.fontFamily;

            const currentSettings = this.core.state.get("settings") || {};

            if (this.core.settingsService) {

                const nextSettings = {
                    ...currentSettings,
                    editor: {
                        ...(currentSettings.editor || {}),
                        fontFamily: this.editorSettings.fontFamily,
                        fontSize: this.editorSettings.fontSize,
                        lineHeight: this.editorSettings.lineHeight,
                        editorWidth: this.editorSettings.editorWidth,
                        spellcheck: this.editorSettings.spellcheck
                    }
                };

                this.core.settingsService.saveSettings(nextSettings);

            } else {

                const nextSettings = {
                    ...currentSettings,
                    manuscriptEditor: {
                        ...this.editorSettings
                    }
                };

                this.core.state.set("settings", nextSettings);
                this.core.storage.saveSettings(nextSettings);

            }

            this.core.notify("Editor settings updated.", "success");

            const editor = this.container?.querySelector("#manuscript-editor");

            if (editor) {
                editor.style.setProperty("--editor-font-size", `${this.editorSettings.fontSize}px`);
                editor.style.setProperty("--editor-line-height", String(this.editorSettings.lineHeight));
                editor.style.setProperty("--editor-font-family", this.getEditorFontFamilyStack(this.editorSettings.fontFamily));
                editor.spellcheck = this.editorSettings.spellcheck;
            }

            this.render(this.container);

        },


        cloneData(value) {

            try {
                return JSON.parse(JSON.stringify(value));
            } catch (error) {
                console.error("Writing editor clone failed:", error);
                return null;
            }

        },


        bindModalBackdrop() {

            const backdrop = this.modalContainer?.querySelector(".project-modal-backdrop");

            if (!backdrop) {
                return;
            }

            backdrop.addEventListener("click", event => {
                if (event.target === backdrop) {
                    this.closeModal();
                }
            });

        },


        closeModal() {

            if (!this.modalContainer) {
                return;
            }

            this.modalContainer.classList.remove("active");
            this.modalContainer.innerHTML = "";

        },


        escapeHTML(value) {
            return AuthorOSHelpers.escapeHTML(value);
        },


        getEditorFontFamilies() {

            return [
                { value: "merriweather", label: "Merriweather", stack: '"Merriweather", Georgia, serif' },
                { value: "inter", label: "Inter", stack: '"Inter", "Segoe UI", Arial, sans-serif' },
                { value: "jetbrains-mono", label: "JetBrains Mono", stack: '"JetBrains Mono", "Courier New", monospace' },
                { value: "georgia", label: "Georgia", stack: 'Georgia, "Times New Roman", serif' },
                { value: "times-new-roman", label: "Times New Roman", stack: '"Times New Roman", Times, serif' },
                { value: "garamond", label: "Garamond", stack: 'Garamond, "Palatino Linotype", serif' },
                { value: "palatino", label: "Palatino", stack: '"Palatino Linotype", Palatino, serif' },
                { value: "arial", label: "Arial", stack: 'Arial, "Helvetica Neue", sans-serif' },
                { value: "verdana", label: "Verdana", stack: 'Verdana, Geneva, sans-serif' },
                { value: "courier-new", label: "Courier New", stack: '"Courier New", Courier, monospace' }
            ];

        },


        getEditorFontFamilyOptionsMarkup() {

            return this.getEditorFontFamilies()
                .map(option => `
                    <option value="${this.escapeHTML(option.value)}" ${this.editorSettings.fontFamily === option.value ? "selected" : ""}>
                        ${this.escapeHTML(option.label)}
                    </option>
                `)
                .join("");

        },


        getEditorFontFamilyStack(fontFamily) {

            const selected =
                this.getEditorFontFamilies()
                    .find(item => item.value === String(fontFamily || "").trim());

            return selected?.stack || '"Merriweather", Georgia, serif';

        }

    };

})();
