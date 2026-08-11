/*
=========================================================
AUTHOROS
CHAPTERS MODULE
Version 0.1.0
=========================================================
*/

(function () {

    "use strict";

    window.AuthorOSChapters = {

        name: "chapters",

        core: null,
        container: null,
        activeChapterId: null,

        initialize(core) {
            this.core = core;
        },


        render(container) {

            if (!container) {
                return;
            }

            this.container = container;

            const manuscriptModule = this.getManuscriptModule();

            if (!manuscriptModule) {
                container.innerHTML = this.renderUnavailableState();
                this.bindStaticEvents(container);
                return;
            }

            const project = this.getActiveProject(manuscriptModule);

            if (!project) {
                container.innerHTML = this.renderMissingProjectState();
                this.bindStaticEvents(container);
                return;
            }

            const hydrated = manuscriptModule.ensureManuscriptShape(project);

            if (hydrated?.changed) {
                manuscriptModule.persistProject(hydrated.project, "chapters-hydrate");
            }

            const freshProject = manuscriptModule.getProjectById(project.id) || hydrated.project || project;
            const chapters = manuscriptModule.getChapters(freshProject);
            const totalWords = manuscriptModule.getTotalWordCount(chapters);
            const targetWords = manuscriptModule.getGoalTargetWords(freshProject);
            const progress = manuscriptModule.getGoalProgress(totalWords, targetWords);
            const activeChapter = this.resolveActiveChapter(freshProject, chapters, manuscriptModule);

            container.innerHTML = this.renderOverview(
                freshProject,
                chapters,
                totalWords,
                progress,
                activeChapter,
                manuscriptModule
            );

            this.bindStaticEvents(container);
            this.bindChapterEvents(container, freshProject.id);

        },


        getManuscriptModule() {
            return this.core?.registry?.get("manuscript") || null;
        },


        getActiveProject(manuscriptModule) {

            if (manuscriptModule && typeof manuscriptModule.getActiveProject === "function") {
                return manuscriptModule.getActiveProject();
            }

            const currentProject = this.core?.state?.get("currentProject");

            if (currentProject && typeof currentProject === "object") {
                return currentProject;
            }

            const activeProjectId = this.core?.storage?.loadActiveProjectId?.();

            if (!activeProjectId) {
                return null;
            }

            const projects = this.core?.state?.get("projects");

            if (!Array.isArray(projects)) {
                return null;
            }

            return projects.find(project => project.id === activeProjectId) || null;

        },


        renderUnavailableState() {

            return `
                <section class="empty-view">
                    <div class="empty-view-icon">◇</div>
                    <p class="eyebrow">AUTHOR STUDIO WORKSPACE</p>
                    <h1>Chapters</h1>
                    <p>Chapter services are unavailable right now.</p>
                    <button type="button" class="button button-primary" data-action="open-library">
                        Open Story Library
                    </button>
                </section>
            `;

        },


        renderMissingProjectState() {

            return `
                <section class="manuscript-missing-project">
                    <div class="empty-view-icon">*</div>
                    <p class="eyebrow">CHAPTER OVERVIEW</p>
                    <h1>No active project</h1>
                    <p>Open a project from Story Library to browse its chapters.</p>
                    <div class="manuscript-missing-actions">
                        <button type="button" class="button button-primary" data-action="open-library">
                            Open Story Library
                        </button>
                    </div>
                </section>
            `;

        },


        renderOverview(project, chapters, totalWords, progress, activeChapter, manuscriptModule) {

            const projectName = manuscriptModule.escapeHTML(project.name || project.title || "Project");
            const projectSubtitle = `${chapters.length} chapter${chapters.length === 1 ? "" : "s"} | ${totalWords.toLocaleString()} words`;
            const averageWords = chapters.length
                ? Math.round(totalWords / chapters.length)
                : 0;

            return `
                <section class="manuscript-studio-view">

                    <header class="manuscript-studio-header">
                        <div>
                            <p class="eyebrow">CHAPTER OVERVIEW</p>
                            <h1 title="${projectName}">${projectName}</h1>
                            <p class="manuscript-studio-subtitle">${projectSubtitle}</p>
                        </div>

                        <div class="manuscript-studio-header-actions">
                            <button type="button" class="button button-primary" data-action="create-chapter">
                                + Chapter
                            </button>
                            <button type="button" class="button button-secondary" data-action="open-library">
                                Story Library
                            </button>
                            <button type="button" class="button button-primary" data-action="open-manuscript">
                                Open Manuscript Studio
                            </button>
                        </div>
                    </header>

                    <div class="manuscript-studio-layout">

                        <aside class="manuscript-chapter-panel" aria-label="Chapter list">
                            <div class="manuscript-panel-header">
                                <h2>Chapters</h2>
                                <span class="manuscript-save-status">${chapters.length.toLocaleString()} total</span>
                            </div>

                            ${
                                chapters.length
                                    ? `
                                        <ol class="manuscript-chapter-list chapters-overview-list">
                                            ${chapters.map(chapter => this.renderChapterListItem(chapter, manuscriptModule)).join("")}
                                        </ol>
                                    `
                                    : `
                                        <div class="manuscript-empty-state">
                                            <h3>No chapters yet</h3>
                                            <p>Create your first chapter here, then jump into the editor when you're ready to draft.</p>
                                            <button type="button" class="button button-primary" data-action="create-chapter">
                                                Create Chapter
                                            </button>
                                        </div>
                                    `
                            }
                        </aside>

                        <section class="manuscript-editor-panel" aria-label="Chapter details">
                            ${this.renderChapterDetailPanel(activeChapter, totalWords, manuscriptModule)}
                        </section>

                        <aside class="manuscript-meta-panel" aria-label="Chapter statistics">
                            <section class="manuscript-stat-card">
                                <h3>Total Chapters</h3>
                                <p>${chapters.length.toLocaleString()}</p>
                            </section>

                            <section class="manuscript-stat-card">
                                <h3>Total Words</h3>
                                <p>${totalWords.toLocaleString()}</p>
                            </section>

                            <section class="manuscript-stat-card">
                                <h3>Average Chapter</h3>
                                <p>${averageWords.toLocaleString()}</p>
                            </section>

                            <section class="manuscript-goal-card">
                                <h3>Writing Goal</h3>
                                <p id="chapters-goal-progress">${progress.label}</p>
                                <progress id="chapters-goal-bar" max="100" value="${progress.percent}"></progress>
                            </section>

                            <section class="manuscript-stat-card">
                                <h3>Last Updated</h3>
                                <p>${this.formatDate(project.updatedAt || project.lastModified || project.createdAt)}</p>
                            </section>
                        </aside>

                    </div>

                </section>
            `;

        },


        renderChapterListItem(chapter, manuscriptModule) {

            const title = manuscriptModule.escapeHTML(chapter.title || `Chapter ${chapter.order}`);
            const preview = manuscriptModule.escapeHTML(this.getPreviewText(chapter.content));
            const updatedAt = this.formatDate(chapter.updatedAt || chapter.createdAt);
            const createdAt = this.formatDate(chapter.createdAt);
            const wordCount = Number(chapter.wordCount || 0);
            const isActive = chapter.id === this.activeChapterId;

            return `
                <li class="manuscript-chapter-item chapters-overview-card ${isActive ? "active" : ""}" data-chapter-id="${manuscriptModule.escapeHTML(chapter.id)}">
                    <button type="button" class="chapters-overview-select" data-action="select-chapter" data-chapter-id="${manuscriptModule.escapeHTML(chapter.id)}">
                        <span class="chapters-overview-index">Chapter ${chapter.order}</span>
                        <span class="chapters-overview-title">${title}</span>
                        <span class="chapters-overview-meta">${wordCount.toLocaleString()} words • ${this.getReadingTimeLabel(wordCount)}</span>
                    </button>

                    <div class="chapters-overview-tags" aria-label="Chapter metadata">
                        <span class="chapter-action" aria-hidden="true">Updated ${updatedAt}</span>
                        <span class="chapter-action" aria-hidden="true">Created ${createdAt}</span>
                    </div>

                    <p class="chapters-overview-preview">${preview}</p>

                    <div class="manuscript-chapter-actions">
                        <button type="button" class="chapter-action" data-action="select-chapter" data-chapter-id="${manuscriptModule.escapeHTML(chapter.id)}">Details</button>
                        <button type="button" class="chapter-action" data-action="open-chapter-editor" data-chapter-id="${manuscriptModule.escapeHTML(chapter.id)}">Open in Editor</button>
                    </div>
                </li>
            `;

        },


        renderChapterDetailPanel(chapter, totalWords, manuscriptModule) {

            if (!chapter) {
                return `
                    <div class="manuscript-empty-editor">
                        <h2>Select a chapter</h2>
                        <p>Choose a chapter card to inspect its metadata and preview before opening the editor.</p>
                    </div>
                `;
            }

            const title = manuscriptModule.escapeHTML(chapter.title || `Chapter ${chapter.order}`);
            const preview = manuscriptModule.escapeHTML(this.getLongPreviewText(chapter.content));
            const wordCount = Number(chapter.wordCount || 0);
            const share = totalWords > 0
                ? Math.round((wordCount / totalWords) * 100)
                : 0;

            return `
                <article class="chapters-detail-panel">
                    <header class="chapters-detail-header">
                        <div>
                            <p class="eyebrow">CHAPTER ${chapter.order}</p>
                            <h2>${title}</h2>
                            <p class="manuscript-studio-subtitle">${wordCount.toLocaleString()} words • ${this.getReadingTimeLabel(wordCount)}</p>
                        </div>

                        <div class="chapters-detail-actions">
                            <button type="button" class="button button-primary" data-action="open-chapter-editor" data-chapter-id="${manuscriptModule.escapeHTML(chapter.id)}">
                                Open in Editor
                            </button>
                        </div>
                    </header>

                    <div class="chapters-detail-grid">
                        <section class="manuscript-stat-card">
                            <h3>Draft Share</h3>
                            <p>${share}%</p>
                        </section>

                        <section class="manuscript-stat-card">
                            <h3>Created</h3>
                            <p class="chapters-detail-small">${this.formatDate(chapter.createdAt)}</p>
                        </section>

                        <section class="manuscript-stat-card">
                            <h3>Updated</h3>
                            <p class="chapters-detail-small">${this.formatDate(chapter.updatedAt || chapter.createdAt)}</p>
                        </section>
                    </div>

                    <section class="chapters-detail-preview">
                        <h3>Preview</h3>
                        <p>${preview}</p>
                    </section>
                </article>
            `;

        },


        bindStaticEvents(container) {

            container.querySelectorAll('[data-action="create-chapter"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();

                    const manuscriptModule = this.getManuscriptModule();
                    const project = this.getActiveProject(manuscriptModule);

                    if (!project?.id) {
                        this.core.notify("Open a project before creating a chapter.", "error");
                        return;
                    }

                    this.createChapter(project.id);
                });
            });

            container.querySelectorAll('[data-action="open-library"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.core.navigation.navigate("projects");
                });
            });

            container.querySelectorAll('[data-action="open-manuscript"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.core.navigation.navigate("manuscript");
                });
            });

        },


        bindChapterEvents(container, projectId) {

            container.querySelectorAll('[data-action="select-chapter"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.activeChapterId = button.dataset.chapterId || null;
                    this.render(this.container);
                });
            });

            container.querySelectorAll('[data-action="open-chapter-editor"]').forEach(button => {
                button.addEventListener("click", event => {
                    event.preventDefault();
                    this.openChapterInManuscript(projectId, button.dataset.chapterId);
                });
            });

        },


        openChapterInManuscript(projectId, chapterId) {

            if (!projectId || !chapterId) {
                return;
            }

            const manuscriptModule = this.getManuscriptModule();

            if (!manuscriptModule) {
                this.core.notify("Manuscript Studio is unavailable.", "error");
                return;
            }

            const project = manuscriptModule.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const hydrated = manuscriptModule.ensureManuscriptShape(project);
            const next = manuscriptModule.cloneData(hydrated.project || project);

            if (next?.manuscript) {
                const now = new Date().toISOString();
                next.manuscript.lastOpenedChapterId = chapterId;
                next.updatedAt = now;
                next.lastModified = now;
                manuscriptModule.persistProject(next, "chapters-open-link");
            }

            manuscriptModule.activeChapterId = chapterId;
            this.core.navigation.navigate("manuscript");

        },


        createChapter(projectId) {

            const manuscriptModule = this.getManuscriptModule();

            if (!manuscriptModule) {
                this.core.notify("Manuscript Studio is unavailable.", "error");
                return;
            }

            const project = manuscriptModule.getProjectById(projectId);

            if (!project) {
                this.core.notify("Project could not be found.", "error");
                return;
            }

            const hydrated = manuscriptModule.ensureManuscriptShape(project);
            const next = manuscriptModule.cloneData(hydrated.project);

            if (!next) {
                this.core.notify("Unable to create chapter.", "error");
                return;
            }

            const chapters = manuscriptModule.getChapters(next);
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
                words: manuscriptModule.getTotalWordCount(next.manuscript.chapters),
                chapters: next.manuscript.chapters.length
            };

            if (!manuscriptModule.persistProject(next, "chapters-create")) {
                this.core.notify("Failed to create chapter.", "error");
                return;
            }

            this.activeChapterId = newChapter.id;

            this.core.events.emit("chapter:created", {
                projectId,
                chapterId: newChapter.id,
                chapter: newChapter
            });

            this.core.notify("Chapter created.", "success");
            this.render(this.container);

        },


        resolveActiveChapter(project, chapters, manuscriptModule) {

            if (!Array.isArray(chapters) || !chapters.length) {
                this.activeChapterId = null;
                return null;
            }

            if (this.activeChapterId && chapters.some(chapter => chapter.id === this.activeChapterId)) {
                return chapters.find(chapter => chapter.id === this.activeChapterId) || null;
            }

            const preferredId = typeof manuscriptModule.getPreferredChapterId === "function"
                ? manuscriptModule.getPreferredChapterId(project, chapters)
                : chapters[0].id;

            this.activeChapterId = preferredId;

            return chapters.find(chapter => chapter.id === preferredId) || chapters[0] || null;

        },


        getPreviewText(content) {

            const text = String(content || "")
                .replace(/\s+/g, " ")
                .trim();

            if (!text) {
                return "No draft content yet.";
            }

            if (text.length <= 140) {
                return text;
            }

            return `${text.slice(0, 137)}...`;

        },


        getLongPreviewText(content) {

            const text = String(content || "")
                .replace(/\s+/g, " ")
                .trim();

            if (!text) {
                return "No draft content yet. Create the chapter here, then open it in the editor to begin writing scenes, beats, and prose.";
            }

            if (text.length <= 480) {
                return text;
            }

            return `${text.slice(0, 477)}...`;

        },


        getReadingTimeLabel(wordCount) {

            const safeCount = Math.max(0, Number(wordCount) || 0);

            if (!safeCount) {
                return "0 min read";
            }

            const minutes = Math.max(1, Math.ceil(safeCount / 200));

            return `${minutes} min read`;

        },


        formatDate(value) {

            if (!value) {
                return "No recent updates";
            }

            const date = new Date(value);

            if (Number.isNaN(date.getTime())) {
                return "No recent updates";
            }

            return date.toLocaleString();

        }

    };

})();